//
//  GeminiService.swift
//  Pantry Pal
//

import Foundation
import GoogleGenerativeAI
import AVFoundation
import Speech
import FirebaseFirestore

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
    @Published var pendingPantryAction: PantryAction?
    weak var firestoreService: FirestoreService?
    weak var authService: AuthenticationService?
    enum PantryAction {
        case addIngredient(name: String, quantity: Double, unit: String, category: String)
        case editIngredient(id: String, name: String, quantity: Double, unit: String, category: String)
        case deleteIngredient(id: String)
        case updateQuantity(id: String, newQuantity: Double)
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
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["GEMINI_API_KEY"] as? String else {
            fatalError("Could not load Gemini API key from GoogleService-Info.plist")
        }
        
        let systemPrompt = ModelContent(parts: [
            .text("""
            You are Pantry Pal, a friendly and bubbly AI assistant for a pantry management app! 
            
            Your personality:
            - Super enthusiastic about food and cooking
            - Always positive and encouraging
            - Use food-related emojis and expressions
            - Make cooking feel fun and accessible
            - Give practical, helpful advice
            
            Your capabilities:
            - Help users manage their pantry ingredients (ADD, EDIT, DELETE, UPDATE)
            - Suggest recipes based on available ingredients
            - Answer cooking and food storage questions
            - Give meal planning advice
            - Help with grocery shopping suggestions
            - Provide food safety information
            - View and discuss current pantry contents
            
            PANTRY MANAGEMENT:
            When users want to manage their pantry, respond with valid JSON followed by a friendly message.
            
            JSON Format (use ONLY these exact fields with valid numbers):
            {
                "action": "add_ingredient",
                "name": "ingredient_name",
                "quantity": 2.0,
                "unit": "cups",
                "category": "Grains"
            }
            
            Valid actions: "add_ingredient", "edit_ingredient", "delete_ingredient", "update_quantity"
            Valid categories: "Produce", "Dairy", "Meat", "Grains", "Spices", "Condiments", "Other"
            
            PANTRY VIEWING AND RECIPES:
            When users ask about their pantry contents or want recipe suggestions, use the pantry context provided in each message.
            Be specific about what ingredients they have and suggest realistic recipes.
            
            IMPORTANT: 
            - Always use valid numbers for quantity (never NaN, infinity, or text)
            - Include both JSON and a friendly response
            - If unsure about details, ask the user for clarification
            - Reference specific ingredients from their pantry when making suggestions
            
            Keep responses conversational, helpful, and under 100 words when possible.
            """)
        ])
        
        self.model = GenerativeModel(
            name: "gemini-1.5-flash",
            apiKey: apiKey,
            systemInstruction: systemPrompt
        )
        
        super.init()
        
        setupChat()
        configureAudioSession()
        requestSpeechAuthorization()
        
        // Set up TTS delegate
        speechSynthesizer.delegate = self
        
        validateConfiguration()
    }
    
    func configure(firestoreService: FirestoreService, authService: AuthenticationService) {
        self.firestoreService = firestoreService
        self.authService = authService
    }

    // Add pantry management functions
    func handlePantryRequest(_ message: String) async {
        // Enhance the system prompt to include pantry management capabilities
        let pantryPrompt = """
        \(message)
        
        If the user wants to add, edit, delete, or update ingredients in their pantry, respond with a JSON action in this format:
        {
            "action": "add_ingredient" | "edit_ingredient" | "delete_ingredient" | "update_quantity",
            "ingredient_id": "id_if_editing_or_deleting",
            "name": "ingredient_name",
            "quantity": number,
            "unit": "unit_string",
            "category": "category_string"
        }
        
        If it's a general food question, respond normally with friendly advice.
        """
        
        do {
            let response = try await chat?.sendMessage(pantryPrompt)
            if let responseText = response?.text {
                // Check if response contains a JSON action
                if let action = parseActionFromResponse(responseText) {
                    await executePantryAction(action)
                } else {
                    // Regular chat response
                    currentResponse = responseText
                    let aiMessage = ChatMessage(text: responseText, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(responseText)
                }
            }
        } catch {
            let errorMessage = "I had trouble with that pantry request. Could you try again?"
            let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
            conversationHistory.append(aiMessage)
            speak(errorMessage)
        }
    }
    
    private func getCurrentPantryContext() -> String {
        guard let firestoreService = firestoreService,
              !firestoreService.ingredients.isEmpty else {
            return "The user currently has no ingredients in their pantry."
        }
        
        let ingredientsList = firestoreService.ingredients.map { ingredient in
            "\(ingredient.name): \(ingredient.safeDisplayQuantity) \(ingredient.unit) (Category: \(ingredient.category))"
        }.joined(separator: "\n")
        
        return """
        Current pantry contents:
        \(ingredientsList)
        
        Total ingredients: \(firestoreService.ingredients.count)
        """
    }

    private func parseActionFromResponse(_ response: String) -> PantryAction? {
        // Look for JSON in the response - handle both pure JSON and JSON within text
        let jsonPattern = #"\{[\s\S]*?\}"#
        guard let regex = try? NSRegularExpression(pattern: jsonPattern),
              let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range, in: response) else {
            return nil
        }
        
        let jsonString = String(response[range])
        
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let actionType = json["action"] as? String else {
            return nil
        }
        
        switch actionType {
        case "add_ingredient":
            guard let name = json["name"] as? String,
                  let quantityValue = json["quantity"],
                  let unit = json["unit"] as? String,
                  let category = json["category"] as? String else { return nil }
            
            // Safely convert quantity to Double
            let quantity: Double
            if let doubleValue = quantityValue as? Double, doubleValue.isFinite {
                quantity = doubleValue
            } else if let intValue = quantityValue as? Int {
                quantity = Double(intValue)
            } else if let stringValue = quantityValue as? String,
                      let parsedValue = Double(stringValue), parsedValue.isFinite {
                quantity = parsedValue
            } else {
                return nil // Invalid quantity
            }
            
            return .addIngredient(name: name, quantity: quantity, unit: unit, category: category)
            
        case "edit_ingredient":
            guard let id = json["ingredient_id"] as? String,
                  let name = json["name"] as? String,
                  let quantityValue = json["quantity"],
                  let unit = json["unit"] as? String,
                  let category = json["category"] as? String else { return nil }
            
            // Safely convert quantity to Double
            let quantity: Double
            if let doubleValue = quantityValue as? Double, doubleValue.isFinite {
                quantity = doubleValue
            } else if let intValue = quantityValue as? Int {
                quantity = Double(intValue)
            } else if let stringValue = quantityValue as? String,
                      let parsedValue = Double(stringValue), parsedValue.isFinite {
                quantity = parsedValue
            } else {
                return nil // Invalid quantity
            }
            
            return .editIngredient(id: id, name: name, quantity: quantity, unit: unit, category: category)
            
        case "delete_ingredient":
            guard let id = json["ingredient_id"] as? String else { return nil }
            return .deleteIngredient(id: id)
            
        case "update_quantity":
            guard let id = json["ingredient_id"] as? String,
                  let quantityValue = json["quantity"] else { return nil }
            
            // Safely convert quantity to Double
            let quantity: Double
            if let doubleValue = quantityValue as? Double, doubleValue.isFinite {
                quantity = doubleValue
            } else if let intValue = quantityValue as? Int {
                quantity = Double(intValue)
            } else if let stringValue = quantityValue as? String,
                      let parsedValue = Double(stringValue), parsedValue.isFinite {
                quantity = parsedValue
            } else {
                return nil // Invalid quantity
            }
            
            return .updateQuantity(id: id, newQuantity: quantity)
            
        default:
            return nil
        }
    }

    private func executePantryAction(_ action: PantryAction) async {
        guard let firestoreService = firestoreService,
              let authService = authService,
              let userId = authService.user?.id else {
            let errorMessage = "I can't access your pantry right now. Please make sure you're logged in!"
            let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
            conversationHistory.append(aiMessage)
            speak(errorMessage)
            return
        }
        
        do {
            switch action {
            case .addIngredient(let name, let quantity, let unit, let category):
                // Validate inputs
                guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
                      quantity > 0 && quantity.isFinite,
                      !unit.trimmingCharacters(in: .whitespaces).isEmpty else {
                    let errorMessage = "Sorry, I need valid ingredient details to add to your pantry!"
                    let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(errorMessage)
                    return
                }
                
                let ingredient = Ingredient.createSafe(
                    name: name.trimmingCharacters(in: .whitespaces),
                    quantity: quantity,
                    unit: unit.trimmingCharacters(in: .whitespaces),
                    category: category.trimmingCharacters(in: .whitespaces),
                    userId: userId
                )
                try await firestoreService.addIngredient(ingredient)
                let successMessage = "Great! I've added \(quantity.safeFormattedString) \(unit) of \(name) to your pantry! 🎉"
                let aiMessage = ChatMessage(text: successMessage, isUser: false, timestamp: Date())
                conversationHistory.append(aiMessage)
                speak(successMessage)
                
            case .editIngredient(let id, let name, let quantity, let unit, let category):
                // Validate inputs
                guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
                      quantity > 0 && quantity.isFinite,
                      !unit.trimmingCharacters(in: .whitespaces).isEmpty else {
                    let errorMessage = "Sorry, I need valid ingredient details to update your pantry!"
                    let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(errorMessage)
                    return
                }
                
                if let existingIngredient = firestoreService.ingredients.first(where: { $0.id == id }) {
                    let updatedIngredient = Ingredient(
                        id: id,
                        name: name.trimmingCharacters(in: .whitespaces),
                        quantity: quantity,
                        unit: unit.trimmingCharacters(in: .whitespaces),
                        category: category.trimmingCharacters(in: .whitespaces),
                        expirationDate: existingIngredient.expirationDate,
                        dateAdded: existingIngredient.dateAdded,
                        notes: existingIngredient.notes,
                        inTrash: existingIngredient.inTrash,
                        trashedAt: existingIngredient.trashedAt,
                        createdAt: existingIngredient.createdAt,
                        updatedAt: Timestamp(date: Date()),
                        userId: userId,
                        fatSecretFoodId: existingIngredient.fatSecretFoodId,
                        brandName: existingIngredient.brandName,
                        barcode: existingIngredient.barcode,
                        nutritionInfo: existingIngredient.nutritionInfo,
                        servingInfo: existingIngredient.servingInfo
                    )
                    try await firestoreService.updateIngredient(updatedIngredient)
                    let successMessage = "Perfect! I've updated \(name) in your pantry! ✨"
                    let aiMessage = ChatMessage(text: successMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(successMessage)
                } else {
                    let errorMessage = "I couldn't find that ingredient to update. Could you try again?"
                    let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(errorMessage)
                }
                
            case .deleteIngredient(let id):
                try await firestoreService.deleteIngredient(id)
                let successMessage = "Done! I've removed that ingredient from your pantry! 🗑️"
                let aiMessage = ChatMessage(text: successMessage, isUser: false, timestamp: Date())
                conversationHistory.append(aiMessage)
                speak(successMessage)
                
            case .updateQuantity(let id, let newQuantity):
                // Validate quantity
                guard newQuantity >= 0 && newQuantity.isFinite else {
                    let errorMessage = "Sorry, I need a valid quantity to update!"
                    let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(errorMessage)
                    return
                }
                
                if let existingIngredient = firestoreService.ingredients.first(where: { $0.id == id }) {
                    let updatedIngredient = Ingredient(
                        id: id,
                        name: existingIngredient.name,
                        quantity: newQuantity,
                        unit: existingIngredient.unit,
                        category: existingIngredient.category,
                        expirationDate: existingIngredient.expirationDate,
                        dateAdded: existingIngredient.dateAdded,
                        notes: existingIngredient.notes,
                        inTrash: existingIngredient.inTrash,
                        trashedAt: existingIngredient.trashedAt,
                        createdAt: existingIngredient.createdAt,
                        updatedAt: Timestamp(date: Date()),
                        userId: userId,
                        fatSecretFoodId: existingIngredient.fatSecretFoodId,
                        brandName: existingIngredient.brandName,
                        barcode: existingIngredient.barcode,
                        nutritionInfo: existingIngredient.nutritionInfo,
                        servingInfo: existingIngredient.servingInfo
                    )
                    try await firestoreService.updateIngredient(updatedIngredient)
                    let successMessage = "Updated! \(existingIngredient.name) now shows \(newQuantity) \(existingIngredient.unit)! 📝"
                    let aiMessage = ChatMessage(text: successMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(successMessage)
                } else {
                    let errorMessage = "I couldn't find that ingredient to update. Could you try again?"
                    let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(errorMessage)
                }
            }
        } catch {
            print("❌ Pantry action error: \(error)")
            let errorMessage = "Oops! I had trouble updating your pantry. Could you try that again?"
            let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
            conversationHistory.append(aiMessage)
            speak(errorMessage)
        }
    }
    
    // Replace the existing requestSpeechAuthorization method
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
    
    private func setupChat() {
        chat = model.startChat()
        print("✅ Chat initialized")
    }
    
    private func validateConfiguration() {
        guard let _ = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("❌ ERROR: GoogleService-Info.plist not found")
            connectionStatus = .error("Configuration file missing")
            return
        }
        
        // Simple check to ensure model exists
        guard chat != nil else {
            print("❌ ERROR: Gemini model not properly initialized")
            connectionStatus = .error("AI model initialization failed")
            return
        }
        
        print("✅ GeminiService initialized successfully")
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
                connectionStatus = .error("Unable to create recognition request")
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            
            // Check if audio engine is running and stop if needed
            if audioEngine.isRunning {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Validate recording format
            guard recordingFormat.sampleRate > 0 && !recordingFormat.sampleRate.isNaN else {
                connectionStatus = .error("Invalid audio format")
                return
            }
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("⚠️ Speech recognition error: \(error.localizedDescription)")
                        self.stopListening()
                        self.connectionStatus = .ready
                        return
                    }
                    
                    if let result = result {
                        self.speechRecognitionText = result.bestTranscription.formattedString
                        
                        if result.isFinal {
                            let finalText = result.bestTranscription.formattedString
                            self.stopListening()
                            
                            if !finalText.isEmpty {
                                Task {
                                    await self.sendMessage(finalText)
                                }
                            }
                        }
                    }
                }
            }
            
            isListening = true
            connectionStatus = .listeningForSpeech
            speechRecognitionText = ""
            
        } catch {
            print("⚠️ Failed to start speech recognition: \(error.localizedDescription)")
            connectionStatus = .error("Microphone setup failed")
            stopListening()
        }
    }
    
    func stopListening() {
        isListening = false
        speechRecognitionText = ""
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    // MARK: - Text-to-Speech
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Stop any current speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Configure speech with error handling
        do {
            // Try to use preferred voice, fall back gracefully
            if let voice = AVSpeechSynthesisVoice(language: "en-US") {
                utterance.voice = voice
            } else {
                // Use any available voice as fallback
                utterance.voice = AVSpeechSynthesisVoice.speechVoices().first { voice in
                    voice.language.hasPrefix("en")
                } ?? AVSpeechSynthesisVoice.speechVoices().first
            }
            
            utterance.rate = max(0.1, min(1.0, Float(AVSpeechUtteranceDefaultSpeechRate * 1.1)))
            utterance.pitchMultiplier = max(0.5, min(2.0, 1.1))
            
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
    
    // MARK: - Chat Functions
    func sendMessage(_ message: String, isUser: Bool = true) async {
        if isUser {
            let userMessage = ChatMessage(text: message, isUser: true, timestamp: Date())
            conversationHistory.append(userMessage)
        }
        
        isProcessing = true
        connectionStatus = .processingRequest
        currentResponse = ""
        
        do {
            // Include current pantry context in the prompt
            let pantryContext = getCurrentPantryContext()
            let enhancedMessage = """
            \(pantryContext)
            
            User message: \(message)
            """
            
            let response = try await chat?.sendMessage(enhancedMessage)
            if let responseText = response?.text {
                // Check if response contains a JSON action
                if let action = parseActionFromResponse(responseText) {
                    await executePantryAction(action)
                } else {
                    // Regular chat response
                    currentResponse = responseText
                    let aiMessage = ChatMessage(text: responseText, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(responseText)
                }
            }
        } catch {
            let errorMessage = "I had trouble understanding that. Could you try asking again?"
            let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
            conversationHistory.append(aiMessage)
            speak(errorMessage)
        }
        
        isProcessing = false
        connectionStatus = .ready
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
