//
//  OpenAIService.swift
//  Pantry Pal
//

import Foundation
import OpenAI
import AVFoundation
import Speech
import FirebaseFirestore

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
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["OPENAI_API_KEY"] as? String else {
            fatalError("Could not load OpenAI API key from GoogleService-Info.plist")
        }
        
        self.openAI = OpenAI(apiToken: apiKey)
        
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
                        print("❌ Speech recognition error: \(error)")
                        self.stopListening()
                    }
                }
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isListening = true
            connectionStatus = .listeningForSpeech
            speechRecognitionText = ""
            
        } catch {
            print("❌ Failed to start speech recognition: \(error)")
            connectionStatus = .error("Failed to start listening")
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
        
        if connectionStatus == .listeningForSpeech {
            connectionStatus = .ready
        }
        
        speechRecognitionText = ""
        
        // Reset audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
    }
    
    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    // MARK: - Speech Functions
    private func speak(_ text: String) {
        // Simple speech without dependency on settingsService
        guard !text.isEmpty else { return }
        
        connectionStatus = .speaking
        isSpeaking = true
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSpeaking = false
            if self.connectionStatus == .speaking {
                self.connectionStatus = .ready
            }
        }
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        if connectionStatus == .speaking {
            connectionStatus = .ready
        }
    }
    
    // MARK: - Pantry Intent Processing
    private func processPantryIntent(from userMessage: String, response: String) async {
        let message = userMessage.lowercased()
        
        // Simple intent detection patterns
        if message.contains("add") || message.contains("bought") || message.contains("got") || message.contains("new") {
            await handleAddIngredientIntent(userMessage)
        } else if message.contains("update") || message.contains("change") || message.contains("used") || message.contains("ate") {
            await handleUpdateIngredientIntent(userMessage)
        } else if message.contains("delete") || message.contains("remove") || message.contains("finished") || message.contains("out of") {
            await handleDeleteIngredientIntent(userMessage)
        } else if message.contains("what") || message.contains("show") || message.contains("list") {
            await handleListIngredientsIntent()
        }
    }
    
    private func handleAddIngredientIntent(_ message: String) async {
        // Extract ingredient details using simple pattern matching
        // This is a simplified version - you might want to use more sophisticated NLP
        
        let words = message.components(separatedBy: .whitespaces)
        var ingredientName = ""
        var quantity: Double = 1.0
        var unit = "piece"
        
        // Simple extraction logic
        for (index, word) in words.enumerated() {
            if let number = Double(word) {
                quantity = number
                if index + 1 < words.count {
                    let nextWord = words[index + 1]
                    if ["cups", "cup", "tbsp", "tsp", "oz", "lb", "lbs", "pounds", "grams", "kg"].contains(nextWord.lowercased()) {
                        unit = nextWord
                    }
                }
            } else if !["add", "bought", "got", "new", "i", "have", "some", "a", "an", "the"].contains(word.lowercased()) {
                if ingredientName.isEmpty {
                    ingredientName = word
                } else {
                    ingredientName += " " + word
                }
            }
        }
        
        if !ingredientName.isEmpty {
            pendingPantryAction = .addIngredient(
                name: ingredientName.capitalized,
                quantity: quantity,
                unit: unit,
                category: "Other",
                expirationDate: nil
            )
            
            await executePantryAction()
        }
    }
    
    private func handleUpdateIngredientIntent(_ message: String) async {
        // Similar extraction logic for updates
        let words = message.components(separatedBy: .whitespaces)
        var ingredientName = ""
        var quantity: Double = 0.0
        
        for (index, word) in words.enumerated() {
            if let number = Double(word) {
                quantity = number
            } else if !["update", "change", "used", "ate", "i", "have", "now", "left", "remaining"].contains(word.lowercased()) {
                if ingredientName.isEmpty {
                    ingredientName = word
                } else {
                    ingredientName += " " + word
                }
            }
        }
        
        if !ingredientName.isEmpty && quantity > 0 {
            pendingPantryAction = .updateQuantity(name: ingredientName.capitalized, newQuantity: quantity)
            await executePantryAction()
        }
    }
    
    private func handleDeleteIngredientIntent(_ message: String) async {
        let words = message.components(separatedBy: .whitespaces)
        var ingredientName = ""
        
        for word in words {
            if !["delete", "remove", "finished", "out", "of", "i", "am", "the", "all", "my"].contains(word.lowercased()) {
                if ingredientName.isEmpty {
                    ingredientName = word
                } else {
                    ingredientName += " " + word
                }
            }
        }
        
        if !ingredientName.isEmpty {
            pendingPantryAction = .deleteIngredient(name: ingredientName.capitalized)
            await executePantryAction()
        }
    }
    
    private func handleListIngredientsIntent() async {
        guard let firestoreService = firestoreService,
              let userId = authService?.user?.id else { return }
        
        do {
            await firestoreService.loadIngredients(for: userId)
            let ingredients = firestoreService.ingredients.filter { !$0.inTrash }
            
            if ingredients.isEmpty {
                let response = "Your pantry is currently empty! Would you like to add some ingredients? 📦"
                let aiMessage = PantryChatMessage(text: response, isUser: false, timestamp: Date())
                conversationHistory.append(aiMessage)
                speak(response)
            } else {
                let ingredientList = ingredients.map { "\($0.name): \($0.displayQuantity) \($0.unit)" }.joined(separator: ", ")
                let response = "Here's what you have in your pantry: \(ingredientList) 🥘"
                let aiMessage = PantryChatMessage(text: response, isUser: false, timestamp: Date())
                conversationHistory.append(aiMessage)
                speak(response)
            }
        } catch {
            let errorMessage = "I had trouble checking your pantry. Please try again!"
            let aiMessage = PantryChatMessage(text: errorMessage, isUser: false, timestamp: Date())
            conversationHistory.append(aiMessage)
            speak(errorMessage)
        }
    }
    
    private func executePantryAction() async {
        guard let action = pendingPantryAction,
              let firestoreService = firestoreService,
              let userId = authService?.user?.id else { return }
        
        do {
            switch action {
            case .addIngredient(let name, let quantity, let unit, let category, let expirationDate):
                let timestamp = expirationDate != nil ? Timestamp(date: expirationDate!) : nil
                let ingredient = Ingredient(
                    name: name,
                    quantity: quantity,
                    unit: unit,
                    category: category,
                    expirationDate: timestamp,
                    userId: userId
                )
                try await firestoreService.addIngredient(ingredient)
                
                let successMessage = "Great! I added \(quantity.safeForDisplay) \(unit) of \(name) to your pantry! 🎉"
                let aiMessage = PantryChatMessage(text: successMessage, isUser: false, timestamp: Date())
                conversationHistory.append(aiMessage)
                speak(successMessage)
                
            case .updateQuantity(let name, let newQuantity):
                if let ingredient = await findIngredientByName(name, firestoreService: firestoreService) {
                    // Create a new ingredient with updated quantity since properties are let constants
                    let updatedIngredient = Ingredient(
                        id: ingredient.id,
                        name: ingredient.name,
                        quantity: newQuantity,
                        unit: ingredient.unit,
                        category: ingredient.category,
                        expirationDate: ingredient.expirationDate,
                        dateAdded: ingredient.dateAdded,
                        notes: ingredient.notes,
                        inTrash: ingredient.inTrash,
                        trashedAt: ingredient.trashedAt,
                        createdAt: ingredient.createdAt,
                        updatedAt: Timestamp(date: Date()),
                        userId: ingredient.userId,
                        fatSecretFoodId: ingredient.fatSecretFoodId,
                        brandName: ingredient.brandName,
                        barcode: ingredient.barcode,
                        nutritionInfo: ingredient.nutritionInfo,
                        servingInfo: ingredient.servingInfo
                    )
                    try await firestoreService.updateIngredient(updatedIngredient)
                    
                    let successMessage = "Perfect! I updated your \(name) to \(newQuantity.safeForDisplay) \(ingredient.unit)! ✅"
                    let aiMessage = PantryChatMessage(text: successMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(successMessage)
                } else {
                    let errorMessage = "I couldn't find \(name) in your pantry. Would you like to add it instead?"
                    let aiMessage = PantryChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(errorMessage)
                }
                
            case .deleteIngredient(let name):
                if let ingredient = await findIngredientByName(name, firestoreService: firestoreService) {
                    try await firestoreService.deleteIngredient(ingredient.id!)
                    
                    let successMessage = "Done! I removed \(name) from your pantry! 🗑️"
                    let aiMessage = PantryChatMessage(text: successMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(successMessage)
                } else {
                    let errorMessage = "I couldn't find \(name) in your pantry to remove."
                    let aiMessage = PantryChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(errorMessage)
                }
                
            case .editIngredient(let currentName, let newName, let quantity, let unit, let category, let expirationDate):
                if let ingredient = await findIngredientByName(currentName, firestoreService: firestoreService) {
                    let timestamp = expirationDate != nil ? Timestamp(date: expirationDate!) : ingredient.expirationDate
                    
                    let updatedIngredient = Ingredient(
                        id: ingredient.id,
                        name: newName ?? ingredient.name,
                        quantity: quantity ?? ingredient.quantity,
                        unit: unit ?? ingredient.unit,
                        category: category ?? ingredient.category,
                        expirationDate: timestamp,
                        dateAdded: ingredient.dateAdded,
                        notes: ingredient.notes,
                        inTrash: ingredient.inTrash,
                        trashedAt: ingredient.trashedAt,
                        createdAt: ingredient.createdAt,
                        updatedAt: Timestamp(date: Date()),
                        userId: ingredient.userId,
                        fatSecretFoodId: ingredient.fatSecretFoodId,
                        brandName: ingredient.brandName,
                        barcode: ingredient.barcode,
                        nutritionInfo: ingredient.nutritionInfo,
                        servingInfo: ingredient.servingInfo
                    )
                    
                    try await firestoreService.updateIngredient(updatedIngredient)
                    
                    let successMessage = "Great! I updated your \(currentName) successfully! ✨"
                    let aiMessage = PantryChatMessage(text: successMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(successMessage)
                } else {
                    let errorMessage = "I couldn't find \(currentName) in your pantry to edit."
                    let aiMessage = PantryChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(errorMessage)
                }
            }
        } catch {
            let errorMessage = "I had trouble updating your pantry. Please try again!"
            let aiMessage = PantryChatMessage(text: errorMessage, isUser: false, timestamp: Date())
            conversationHistory.append(aiMessage)
            speak(errorMessage)
        }
        
        pendingPantryAction = nil
    }
    
    private func findIngredientByName(_ name: String, firestoreService: FirestoreService) async -> Ingredient? {
        guard let userId = authService?.user?.id else { return nil }
        
        do {
            await firestoreService.loadIngredients(for: userId)
            return firestoreService.ingredients.first { ingredient in
                ingredient.name.lowercased() == name.lowercased() && !ingredient.inTrash
            }
        } catch {
            print("Error finding ingredient: \(error)")
            return nil
        }
    }
    
    // MARK: - Audio Session and Authorization
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition authorized")
                case .denied:
                    print("❌ Speech recognition denied")
                    self.connectionStatus = .error("Speech recognition denied")
                case .restricted:
                    print("❌ Speech recognition restricted")
                    self.connectionStatus = .error("Speech recognition restricted")
                case .notDetermined:
                    print("❌ Speech recognition not determined")
                    self.connectionStatus = .error("Speech recognition not available")
                @unknown default:
                    print("❌ Speech recognition unknown status")
                    self.connectionStatus = .error("Speech recognition not available")
                }
            }
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord,
                                       mode: .default,
                                       options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session configured successfully")
        } catch {
            print("⚠️ Failed to configure audio session: \(error.localizedDescription)")
            connectionStatus = .error("Audio setup failed")
        }
    }
    
    private func validateConfiguration() {
        guard let _ = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("❌ ERROR: GoogleService-Info.plist not found")
            connectionStatus = .error("Configuration file missing")
            return
        }
        
        print("✅ OpenAIService initialized successfully")
    }
    
    // MARK: - Conversation Management
    func clearConversation() {
        conversationHistory.removeAll()
        conversationMessages.removeAll()
        
        // Re-add system prompt
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
        """
        
        conversationMessages.append(.init(role: .system, content: systemPrompt)!)
        currentResponse = ""
        connectionStatus = .ready
    }
}

// MARK: - Custom Chat Message Model
struct PantryChatMessage: Identifiable, Codable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
}
