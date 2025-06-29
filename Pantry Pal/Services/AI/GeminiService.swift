//
//  GeminiService.swift
//  Pantry Pal
//

import Foundation
import GoogleGenerativeAI
import AVFoundation
import Speech

@MainActor
class GeminiService: NSObject, ObservableObject {
    private let model: GenerativeModel
    private var chat: Chat?
    
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
    @Published var conversationHistory: [ChatMessage] = []
    @Published var connectionStatus: ConnectionStatus = .ready
    @Published var speechRecognitionText = ""
    @Published var firestoreService: FirestoreService?
    
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
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["GEMINI_API_KEY"] as? String else {
            fatalError("Could not load Gemini API key from GoogleService-Info.plist")
        }
        
        let systemPrompt = ModelContent(parts: [
            .text("""
            You are Pantry Pal, a friendly and bubbly AI assistant for a pantry management app! 🥕✨
            
            Your personality:
            - Cheerful, enthusiastic, and food-obsessed
            - Make occasional food puns and jokes
            - Be encouraging about cooking and food management
            - Speak naturally and conversationally since this is voice chat
            - Keep responses concise but engaging for voice interaction
            
            Your capabilities:
            - Help users scan barcodes to add items to their pantry
            - Access and discuss their current pantry inventory (when context is provided)
            - Suggest recipes based on available ingredients in their pantry
            - Talk about food categories, expiration dates, and organization
            - Provide cooking tips and food storage advice
            - Share food-related fun facts
            - Guide users through app actions like "scan that barcode!" or "add it to your pantry!"
            
            IMPORTANT: When users ask about their pantry or what ingredients they have, I will provide you with their current pantry context. Use this information to give accurate, helpful responses about their specific ingredients.
            
            What you CANNOT discuss:
            - Topics unrelated to food, cooking, or pantry management
            - Personal advice outside of food/cooking
            - Politics, controversial topics, or inappropriate content
            
            When users ask about non-food topics, politely redirect them back to food and pantry management with a food joke or pun.
            
            Keep responses conversational and under 3 sentences for voice interaction. Be helpful, encouraging, and maintain your bubbly food-focused personality!
            """)
        ])
        
        model = GenerativeModel(
            name: "gemini-1.5-flash",
            apiKey: apiKey,
            systemInstruction: systemPrompt
        )
        
        super.init()
        
        setupChat()
        setupSpeech()
    }
    
    private func setupChat() {
        chat = model.startChat()
    }
    
    private func setupSpeech() {
        speechSynthesizer.delegate = self
        
        // Configure audio session properly
        configureAudioSession()
        
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("❌ Speech recognition not authorized")
                    self.connectionStatus = .error("Speech recognition not authorized")
                @unknown default:
                    print("❌ Unknown speech recognition status")
                }
            }
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
            DispatchQueue.main.async {
                self.connectionStatus = .error("Audio setup failed")
            }
        }
    }
    
    private func createPantryContext() -> String {
        guard let firestoreService = firestoreService else {
            return "I don't have access to your pantry data right now."
        }
        
        let ingredients = firestoreService.ingredients.filter { !$0.inTrash }
        
        if ingredients.isEmpty {
            return "Your pantry appears to be empty right now."
        }
        
        let ingredientList = ingredients.map { ingredient in
            let status = ingredient.isExpired ? " (expired)" : ingredient.isExpiringSoon ? " (expiring soon)" : ""
            return "- \(ingredient.name): \(ingredient.quantity) \(ingredient.unit)\(status)"
        }.joined(separator: "\n")
        
        return "Here's what's currently in your pantry:\n\(ingredientList)"
    }
    
    // MARK: - Voice Recognition
    func startListening() async {
        guard !isListening else { return }
        
        // Stop any current speech
        stopSpeaking()
        
        // Request microphone permission
        let permissionStatus = await AVAudioApplication.requestRecordPermission()
        guard permissionStatus else {
            connectionStatus = .error("Microphone permission denied")
            return
        }
        
        do {
            try startSpeechRecognition()
            isListening = true
            connectionStatus = .listeningForSpeech
            speechRecognitionText = ""
        } catch {
            connectionStatus = .error("Failed to start listening: \(error.localizedDescription)")
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        stopSpeechRecognition()
        isListening = false
        
        // Process the recognized text if we have any
        if !speechRecognitionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task {
                await sendMessage(speechRecognitionText)
            }
        }
        
        connectionStatus = .ready
    }
    
    private func startSpeechRecognition() throws {
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.recognitionRequestFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Get the audio engine's input node
        let inputNode = audioEngine.inputNode
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.speechRecognitionText = result.bestTranscription.formattedString
                }
                
                if error != nil || result?.isFinal == true {
                    self?.stopSpeechRecognition()
                }
            }
        }
        
        // Set up audio format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func stopSpeechRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    // MARK: - Text-to-Speech
    func speak(_ text: String) {
        stopSpeaking() // Stop any current speech
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1 // Slightly faster
        utterance.pitchMultiplier = 1.1 // Slightly higher pitch for friendliness
        
        isSpeaking = true
        connectionStatus = .speaking
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        if connectionStatus == .speaking {
            connectionStatus = .ready
        }
    }
    
    // MARK: - Chat Functions
    func sendMessage(_ text: String, isUser: Bool = true) async {
        let message = ChatMessage(text: text, isUser: isUser, timestamp: Date())
        conversationHistory.append(message)
        
        if isUser {
            connectionStatus = .processingRequest
            isProcessing = true
            
            // Add pantry context to user messages when they ask about ingredients/pantry
            var messageWithContext = text
            if text.lowercased().contains("pantry") ||
               text.lowercased().contains("ingredient") ||
               text.lowercased().contains("have") ||
               text.lowercased().contains("recipe") {
                let pantryContext = createPantryContext()
                messageWithContext = "\(text)\n\nContext: \(pantryContext)"
            }
            
            do {
                let response = try await chat?.sendMessage(messageWithContext)
                if let responseText = response?.text {
                    currentResponse = responseText
                    let aiMessage = ChatMessage(text: responseText, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    
                    // Speak the response
                    speak(responseText)
                }
            } catch {
                let errorMessage = "Oops! I got a bit mixed up there - like confusing salt with sugar! Could you try asking again?"
                let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                conversationHistory.append(aiMessage)
                speak(errorMessage)
            }
            
            isProcessing = false
            if connectionStatus == .processingRequest {
                connectionStatus = .ready
            }
        }
    }
    
    // MARK: - Barcode Integration
    func handleScannedBarcode(_ barcode: String, fatSecretService: FatSecretService) async {
        connectionStatus = .processingRequest
        isProcessing = true
        
        do {
            // First try to get food info from FatSecret
            if let food = try await fatSecretService.searchFoodByBarcode(barcode) {
                let message = """
                Great! I found that barcode! It's \(food.food_name)! 
                This looks delicious! Would you like me to help you add this to your pantry?
                """
                
                let chatMessage = ChatMessage(text: "Scanned: \(food.food_name)", isUser: true, timestamp: Date())
                conversationHistory.append(chatMessage)
                
                await sendMessage(message, isUser: false)
            } else {
                let message = """
                Hmm, I couldn't find that barcode in my food database. 
                What food were you trying to scan? I can help you add it manually!
                """
                
                let chatMessage = ChatMessage(text: "Scanned unknown barcode", isUser: true, timestamp: Date())
                conversationHistory.append(chatMessage)
                
                await sendMessage(message, isUser: false)
            }
        } catch {
            let message = """
            I had trouble scanning that barcode, but don't worry! 
            Just tell me what food you'd like to add and I'll help you out!
            """
            
            let chatMessage = ChatMessage(text: "Barcode scan failed", isUser: true, timestamp: Date())
            conversationHistory.append(chatMessage)
            
            await sendMessage(message, isUser: false)
        }
        
        isProcessing = false
    }
    
    func clearConversation() {
        conversationHistory.removeAll()
        stopSpeaking()
        setupChat() // Reset the chat
        connectionStatus = .ready
    }
}

// MARK: - Speech Synthesis Delegate
extension GeminiService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            if self.connectionStatus == .speaking {
                self.connectionStatus = .ready
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            if self.connectionStatus == .speaking {
                self.connectionStatus = .ready
            }
        }
    }
}

// MARK: - Models & Errors
struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
}

enum SpeechError: Error {
    case recognitionRequestFailed
    case audioEngineFailed
}
