//
//  OpenAIService.swift
//  Pantry Pal
//

import Foundation
import OpenAI
import AVFoundation
import Speech
import FirebaseFirestore

// MARK: - Custom Chat Message Model
struct PantryChatMessage: Identifiable, Codable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
}

@MainActor
class OpenAIService: NSObject, ObservableObject {
    private let openAI: OpenAI
    private var conversationMessages: [ChatQuery.ChatCompletionMessageParam] = []
    
    // Speech recognition components
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Text-to-speech
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    @Published var isListening = false
    @Published var isProcessing = false
    @Published var isSpeaking = false
    @Published var currentResponse = ""
    @Published var conversationHistory: [PantryChatMessage] = []
    @Published var connectionStatus: ConnectionStatus = .ready
    @Published var speechRecognitionText = ""
    @Published var pendingPantryAction: PantryAction?
    
    weak var firestoreService: FirestoreService?
    weak var authService: AuthenticationService?
    weak var settingsService: SettingsService?
    
    enum PantryAction {
        case addIngredient(name: String, quantity: Double, unit: String, category: String, expirationDate: Date?)
        case editIngredient(currentName: String, newName: String?, quantity: Double?, unit: String?, category: String?, expirationDate: Date?)
        case deleteIngredient(name: String)
        case updateQuantity(name: String, newQuantity: Double)
    }
    
    enum ConnectionStatus: Equatable {
        case ready
        case listeningForSpeech
        case processingRequest
        case speaking
        case error(String)
        
        static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
            switch (lhs, rhs) {
            case (.ready, .ready),
                 (.listeningForSpeech, .listeningForSpeech),
                 (.processingRequest, .processingRequest),
                 (.speaking, .speaking):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    override init() {
        // Try to load from Config.plist first (local development)
        var apiKey: String?
        
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let configPlist = NSDictionary(contentsOfFile: configPath),
           let configApiKey = configPlist["OPENAI_API_KEY"] as? String {
            apiKey = configApiKey
            print("✅ Using OpenAI API key from Config.plist")
        } else {
            print("❌ Config.plist not found or missing OPENAI_API_KEY")
            fatalError("Could not load OpenAI API key. Please ensure Config.plist exists with valid OPENAI_API_KEY")
        }
        
        guard let validApiKey = apiKey else {
            fatalError("Could not load OpenAI API key from Config.plist")
        }
        
        self.openAI = OpenAI(apiToken: validApiKey)
        
        super.init()
        
        // Initialize conversation with system prompt
        let systemPrompt = """
        You are Pantry Pal, a friendly and bubbly AI assistant for a pantry management app!
        
        Your main job is to help users manage their pantry ingredients and suggest recipes. You can:
        
        1. **Add ingredients**: When users say things like "I bought some apples" or "Add 2 cups of flour to my pantry"
        2. **Update quantities**: When they say "I used half of my milk" or "Update my rice to 1 cup"  
        3. **Delete ingredients**: When they say "I finished the eggs" or "Remove the expired bread"
        4. **Answer pantry questions**: "What ingredients do I have?" or "Do I have enough for pasta?"
        5. **Suggest recipes**: "What can I cook for dinner?" or "Recipe ideas with chicken and rice"
        6. **General cooking help**: Cooking tips, substitutions, meal planning advice
        
        Always be enthusiastic, helpful, and encouraging! Use a warm, friendly tone with appropriate emojis. 
        
        When users want to modify their pantry, respond conversationally first, then I'll handle the actual pantry updates.
        
        Keep responses concise but helpful - aim for 1-3 sentences unless they ask for detailed recipes or instructions.
        
        Example responses:
        - "I'd love to help you add those apples! 🍎 How many did you get?"
        - "Great! I can suggest some delicious recipes with your chicken and rice! 🍗🍚"
        - "Perfect! I'll update your milk quantity right away! 🥛"
        """
        
        conversationMessages.append(.init(role: .system, content: systemPrompt)!)
        
        configureAudioSession()
        requestSpeechAuthorization()
        validateConfiguration()
    }
    
    func configure(firestoreService: FirestoreService, authService: AuthenticationService) {
        self.firestoreService = firestoreService
        self.authService = authService
    }
    
    func setSettingsService(_ service: SettingsService) {
        self.settingsService = service
    }
    
    // MARK: - Message Handling
    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isProcessing = true
        connectionStatus = .processingRequest
        
        // Add user message to conversation history
        let userMessage = PantryChatMessage(text: text, isUser: true, timestamp: Date())
        conversationHistory.append(userMessage)
        
        // Add to OpenAI conversation
        conversationMessages.append(.init(role: .user, content: text)!)
        
        do {
            let query = ChatQuery(
                messages: conversationMessages,
                model: .gpt4_o_mini,
                temperature: 0.7
            )
            
            let result = try await openAI.chats(query: query)
            
            if let response = result.choices.first?.message.content {
                let aiMessage = PantryChatMessage(text: response, isUser: false, timestamp: Date())
                self.conversationHistory.append(aiMessage)
                
                // Add AI response to conversation history
                conversationMessages.append(.init(role: .assistant, content: response)!)
                
                currentResponse = response
                
                // Speak the response if enabled (simple check without settingsService dependency)
                speak(response)
                
                // Check for pantry actions
                await processPantryIntent(from: text, response: response)
            }
        } catch {
            print("❌ OpenAI Error: \(error)")
            let errorMessage = "I'm having trouble connecting right now. Please try again!"
            let aiMessage = PantryChatMessage(text: errorMessage, isUser: false, timestamp: Date())
            self.conversationHistory.append(aiMessage)
            speak(errorMessage)
        }
        
        isProcessing = false
        connectionStatus = .ready
    }
    
    // MARK: - Speech Recognition
    func startListening() {
        guard speechRecognizer?.isAvailable == true else {
            connectionStatus = .error("Speech recognition not available")
            return
        }
        
        // Stop any ongoing recognition
        stopListening()
        
        do {
            // Configure audio session with error handling
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                connectionStatus = .error("Unable to create speech recognition request")
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                DispatchQueue.main.async {
                    if let result = result {
                        self.speechRecognitionText = result.bestTranscription.formattedString
                        
                        if result.isFinal {
                            self.stopListening()
                            Task {
                                await self.sendMessage(result.bestTranscription.formattedString)
                            }
                        }
                    }
                    
                    if let error = error {
                        print("Speech recognition error: \(error.localizedDescription)")
                        self.stopListening()
                        self.connectionStatus = .error("Speech recognition failed")
                    }
                }
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isListening = true
            connectionStatus = .listeningForSpeech
            speechRecognitionText = ""
            
        } catch {
            print("Speech recognition setup failed: \(error.localizedDescription)")
            connectionStatus = .error("Speech setup failed")
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        isListening = false
        
        if connectionStatus == .listeningForSpeech {
            connectionStatus = .ready
        }
    }
    
    // MARK: - Text-to-Speech
    func speak(_ text: String) {
        // Simple TTS without settings dependency
        guard !text.isEmpty else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice.speechVoices().first
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
            utterance.pitchMultiplier = 1.1
            
            isSpeaking = true
            connectionStatus = .speaking
            speechSynthesizer.speak(utterance)
            
        } catch {
            print("⚠️ TTS configuration failed: \(error.localizedDescription)")
            isSpeaking = false
            connectionStatus = .ready
        }
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        if connectionStatus == .speaking {
            connectionStatus = .ready
        }
    }
    
    // MARK: - Audio Session Configuration
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session configured successfully")
        } catch {
            print("⚠️ Failed to configure audio session: \(error.localizedDescription)")
            connectionStatus = .error("Audio setup failed")
        }
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("⚠️ Speech recognition not authorized: \(authStatus)")
                    self.connectionStatus = .error("Speech recognition not authorized")
                @unknown default:
                    print("⚠️ Unknown speech recognition authorization status")
                }
            }
        }
    }
    
    private func validateConfiguration() {
        guard let _ = Bundle.main.path(forResource: "Config", ofType: "plist") else {
            print("❌ ERROR: Config.plist not found")
            connectionStatus = .error("Configuration file missing")
            return
        }
        
        print("✅ OpenAIService initialized successfully")
    }
    
    // MARK: - Pantry Integration
    private func processPantryIntent(from userMessage: String, response: String) async {
        // Simple intent detection based on keywords and AI response
        let lowercasedMessage = userMessage.lowercased()
        let lowercasedResponse = response.lowercased()
        
        if (lowercasedMessage.contains("add") || lowercasedMessage.contains("bought") || lowercasedMessage.contains("got")) &&
           (lowercasedResponse.contains("add") || lowercasedResponse.contains("pantry")) {
            
            // Extract ingredient information using basic parsing
            await extractAndAddIngredient(from: userMessage)
            
        } else if (lowercasedMessage.contains("used") || lowercasedMessage.contains("update")) &&
                  (lowercasedResponse.contains("update") || lowercasedResponse.contains("quantity")) {
            
            await extractAndUpdateQuantity(from: userMessage)
            
        } else if (lowercasedMessage.contains("finished") || lowercasedMessage.contains("remove") || lowercasedMessage.contains("delete")) &&
                  (lowercasedResponse.contains("remove") || lowercasedResponse.contains("delete")) {
            
            await extractAndRemoveIngredient(from: userMessage)
        }
    }
    
    private func extractAndAddIngredient(from message: String) async {
        // Basic ingredient extraction - this could be enhanced with more sophisticated NLP
        let words = message.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        
        // Look for quantity patterns
        var quantity: Double = 1.0
        var ingredientName = ""
        var unit = ""
        
        for (index, word) in words.enumerated() {
            if let num = Double(word) {
                quantity = num
                if index + 1 < words.count {
                    unit = words[index + 1]
                }
                if index + 2 < words.count {
                    ingredientName = words[index + 2]
                }
                break
            }
        }
        
        // If no quantity found, look for ingredient names
        if ingredientName.isEmpty {
            let commonIngredients = ["apple", "apples", "milk", "bread", "eggs", "cheese", "chicken", "rice", "pasta"]
            for ingredient in commonIngredients {
                if words.contains(ingredient) {
                    ingredientName = ingredient
                    break
                }
            }
        }
        
        if !ingredientName.isEmpty {
            pendingPantryAction = .addIngredient(
                name: ingredientName.capitalized,
                quantity: quantity,
                unit: unit.isEmpty ? "units" : unit,
                category: "Other",
                expirationDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())
            )
        }
    }
    
    private func extractAndUpdateQuantity(from message: String) async {
        // Similar extraction logic for updates
        let words = message.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        
        var quantity: Double = 0.0
        var ingredientName = ""
        
        for (index, word) in words.enumerated() {
            if let num = Double(word) {
                quantity = num
                break
            }
        }
        
        let commonIngredients = ["milk", "rice", "flour", "sugar", "oil"]
        for ingredient in commonIngredients {
            if words.contains(ingredient) {
                ingredientName = ingredient
                break
            }
        }
        
        if !ingredientName.isEmpty && quantity > 0 {
            pendingPantryAction = .updateQuantity(name: ingredientName.capitalized, newQuantity: quantity)
        }
    }
    
    private func extractAndRemoveIngredient(from message: String) async {
        let words = message.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        
        let commonIngredients = ["eggs", "bread", "milk", "cheese", "apples"]
        for ingredient in commonIngredients {
            if words.contains(ingredient) {
                pendingPantryAction = .deleteIngredient(name: ingredient.capitalized)
                break
            }
        }
    }
}

extension OpenAIService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            if self.connectionStatus == .speaking {
                self.connectionStatus = .ready
            }
        }
    }
}
