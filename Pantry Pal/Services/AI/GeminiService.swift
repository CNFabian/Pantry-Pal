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
            - Edit existing ingredients (name, quantity, unit, category, expiration date)
            
            PANTRY MANAGEMENT:
            When users want to manage their pantry, respond with valid JSON followed by a friendly message.
            
            JSON Format (use ONLY these exact fields with valid numbers):
            For adding new ingredients:
            {
                "action": "add_ingredient",
                "name": "ingredient_name",
                "quantity": 2.0,
                "unit": "cups",
                "category": "Grains",
                "expirationDate": "2024-12-31"
            }
            
            For editing existing ingredients:
            {
                "action": "edit_ingredient",
                "name": "current_ingredient_name",
                "newName": "new_ingredient_name",
                "quantity": 3.0,
                "unit": "pieces",
                "category": "Produce",
                "expirationDate": "2024-12-31"
            }
            
            Valid actions: "add_ingredient", "edit_ingredient", "delete_ingredient", "update_quantity"
            Valid categories: "Produce", "Dairy", "Meat", "Grains", "Spices", "Condiments", "Other"
            
            EXPIRATION DATE HANDLING:
            - When a user provides expiration date information, ALWAYS include it in the JSON
            - If expiration date is missing and user settings allow, ask: "When does this expire? This helps me track freshness!"
            - If a user says something has "no expiration" or "doesn't expire", set expirationDate to null
            - For editing, you can update expiration dates: "expires tomorrow" = tomorrow's date
            
            EDITING INGREDIENTS:
            You can help users modify existing ingredients:
            - Change quantities: "I have 5 apples now" or "Update milk to 2 cups"
            - Change names: "Rename 'leftover chicken' to 'cooked chicken'"
            - Update expiration dates: "My bread expires tomorrow" 
            - Change categories: "Move pasta to grains category"
            
            PANTRY VIEWING AND RECIPES:
            When users ask about their pantry contents or want recipe suggestions, use the pantry context provided in each message.
            Be specific about what ingredients they have and suggest realistic recipes.
            
            IMPORTANT: 
            - Always use valid numbers for quantity (never NaN, infinity, or text)
            - Include both JSON and a friendly response
            - If unsure about details, ask the user for clarification
            - Reference specific ingredients from their pantry when making suggestions
            - For editing, always reference the current ingredient name accurately
            
            Keep responses conversational, helpful, and under 150 words when possible.
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
    
    func setSettingsService(_ settingsService: SettingsService) {
        self.settingsService = settingsService
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
            let expirationText = ingredient.expirationDate?.dateValue().formatted(date: .abbreviated, time: .omitted) ?? "no expiration"
            return "\(ingredient.name): \(ingredient.safeDisplayQuantity) \(ingredient.unit) (Category: \(ingredient.category), Expires: \(expirationText))"
        }.joined(separator: "\n")
        
        return """
        Current pantry contents:
        \(ingredientsList)
        
        Total ingredients: \(firestoreService.ingredients.count)
        """
    }

    private func getSettingsContext() -> String {
        guard let settings = settingsService?.userSettings else {
            return "User Settings: Ask for expiration dates when missing."
        }
        
        let shouldAskForExpiration = settings.aiShouldAskForExpirationDates
        return "User Settings: \(shouldAskForExpiration ? "Ask for expiration dates when missing" : "Do not ask for expiration dates when missing, but use them if provided")."
    }

    private func parseActionFromResponse(_ response: String) -> PantryAction? {
        // Look for JSON in the response
        guard let jsonStart = response.range(of: "{"),
              let jsonEnd = response.range(of: "}", range: jsonStart.upperBound..<response.endIndex) else {
            return nil
        }
        
        let jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
        
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let action = json["action"] as? String {
                
                switch action {
                case "add_ingredient":
                    return parseAddIngredientAction(from: json)
                case "edit_ingredient":
                    return parseEditIngredientAction(from: json)
                case "delete_ingredient":
                    if let name = json["name"] as? String {
                        return .deleteIngredient(name: name)
                    }
                case "update_quantity":
                    if let name = json["name"] as? String,
                       let quantity = parseQuantity(from: json["quantity"]) {
                        return .updateQuantity(name: name, newQuantity: quantity)
                    }
                default:
                    break
                }
            }
        } catch {
            print("JSON parsing error: \(error)")
        }
        
        return nil
    }

    private func parseAddIngredientAction(from json: [String: Any]) -> PantryAction? {
        guard let name = json["name"] as? String,
              let quantity = parseQuantity(from: json["quantity"]),
              let unit = json["unit"] as? String,
              let category = json["category"] as? String else {
            return nil
        }
        
        let expirationDate = parseExpirationDate(from: json["expirationDate"])
        
        return .addIngredient(name: name, quantity: quantity, unit: unit, category: category, expirationDate: expirationDate)
    }

    private func parseEditIngredientAction(from json: [String: Any]) -> PantryAction? {
        guard let currentName = json["name"] as? String else {
            return nil
        }
        
        let newName = json["newName"] as? String
        let quantity = parseQuantity(from: json["quantity"])
        let unit = json["unit"] as? String
        let category = json["category"] as? String
        let expirationDate = parseExpirationDate(from: json["expirationDate"])
        
        return .editIngredient(
            currentName: currentName,
            newName: newName,
            quantity: quantity,
            unit: unit,
            category: category,
            expirationDate: expirationDate
        )
    }

    private func parseExpirationDate(from value: Any?) -> Date? {
        guard let value = value else { return nil }
        
        if let dateString = value as? String, !dateString.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateString)
        }
        
        return nil
    }

    private func parseQuantity(from value: Any?) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue.isValidForUI ? doubleValue : nil
        } else if let intValue = value as? Int {
            return Double(intValue)
        } else if let stringValue = value as? String {
            return Double(stringValue)?.isValidForUI == true ? Double(stringValue) : nil
        }
        return nil
    }

    private func executePantryAction(_ action: PantryAction) async {
        guard let firestoreService = firestoreService,
              let authService = authService,
              let userId = authService.user?.id else {
            let errorMessage = "I couldn't access your pantry right now. Please try again!"
            let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
            conversationHistory.append(aiMessage)
            speak(errorMessage)
            return
        }
        
        do {
            switch action {
            case .addIngredient(let name, let quantity, let unit, let category, let expirationDate):
                let ingredient = Ingredient(
                    name: name,
                    quantity: quantity,
                    unit: unit,
                    category: category,
                    expirationDate: expirationDate.map { Timestamp(date: $0) },
                    userId: userId
                )
                
                try await firestoreService.addIngredient(ingredient)
                
                let expirationText = expirationDate.map {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    return " (expires \(formatter.string(from: $0)))"
                } ?? ""
                
                let successMessage = "Perfect! I've added \(quantity.safeFormattedString) \(unit) of \(name) to your pantry\(expirationText)! 🎉"
                let aiMessage = ChatMessage(text: successMessage, isUser: false, timestamp: Date())
                conversationHistory.append(aiMessage)
                speak(successMessage)
                
            case .editIngredient(let currentName, let newName, let quantity, let unit, let category, let expirationDate):
                // Find the ingredient to edit
                if let existingIngredient = await findIngredientByName(currentName, firestoreService: firestoreService) {
                    let updatedIngredient = Ingredient(
                        id: existingIngredient.id,
                        name: newName ?? existingIngredient.name,
                        quantity: quantity ?? existingIngredient.quantity,
                        unit: unit ?? existingIngredient.unit,
                        category: category ?? existingIngredient.category,
                        expirationDate: expirationDate?.map { Timestamp(date: $0) } ?? existingIngredient.expirationDate,
                        dateAdded: existingIngredient.dateAdded,
                        notes: existingIngredient.notes,
                        inTrash: existingIngredient.inTrash,
                        trashedAt: existingIngredient.trashedAt,
                        createdAt: existingIngredient.createdAt,
                        updatedAt: Timestamp(),
                        userId: userId,
                        fatSecretFoodId: existingIngredient.fatSecretFoodId,
                        brandName: existingIngredient.brandName,
                        barcode: existingIngredient.barcode,
                        nutritionInfo: existingIngredient.nutritionInfo,
                        servingInfo: existingIngredient.servingInfo
                    )
                    
                    try await firestoreService.updateIngredient(updatedIngredient)
                    
                    let successMessage = "Great! I've updated your \(currentName) with the new details! ✨"
                    let aiMessage = ChatMessage(text: successMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(successMessage)
                } else {
                    let errorMessage = "I couldn't find \(currentName) in your pantry. Could you check the name?"
                    let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(errorMessage)
                }
                
            case .deleteIngredient(let name):
                if let existingIngredient = await findIngredientByName(name, firestoreService: firestoreService) {
                    try await firestoreService.moveToTrash(existingIngredient)
                    
                    let successMessage = "I've moved \(name) to the trash for you! 🗑️"
                    let aiMessage = ChatMessage(text: successMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(successMessage)
                } else {
                    let errorMessage = "I couldn't find \(name) in your pantry to remove."
                    let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(errorMessage)
                }
                
            case .updateQuantity(let name, let newQuantity):
                if let existingIngredient = await findIngredientByName(name, firestoreService: firestoreService) {
                    let updatedIngredient = Ingredient(
                        id: existingIngredient.id,
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
                        updatedAt: Timestamp(),
                        userId: userId,
                        fatSecretFoodId: existingIngredient.fatSecretFoodId,
                        brandName: existingIngredient.brandName,
                        barcode: existingIngredient.barcode,
                        nutritionInfo: existingIngredient.nutritionInfo,
                        servingInfo: existingIngredient.servingInfo
                    )
                    
                    try await firestoreService.updateIngredient(updatedIngredient)
                    
                    let successMessage = "Perfect! I've updated \(name) to \(newQuantity.safeFormattedString) \(existingIngredient.unit)! 📝"
                    let aiMessage = ChatMessage(text: successMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(successMessage)
                } else {
                    let errorMessage = "I couldn't find \(name) in your pantry to update."
                    let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                    speak(errorMessage)
                }
            }
        } catch {
            let errorMessage = "I had trouble updating your pantry. Please try again!"
            let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
            conversationHistory.append(aiMessage)
            speak(errorMessage)
        }
    }
    
    private func findIngredientByName(_ name: String, firestoreService: FirestoreService) async -> Ingredient? {
        guard let userId = authService?.user?.id else { return nil }
        
        do {
            let ingredients = try await firestoreService.fetchIngredients(for: userId)
            return ingredients.first { ingredient in
                ingredient.name.lowercased() == name.lowercased() && !ingredient.inTrash
            }
        } catch {
            print("Error finding ingredient: \(error)")
            return nil
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
            // Include current pantry context and settings in the prompt
            let pantryContext = getCurrentPantryContext()
            let settingsContext = getSettingsContext()
            let enhancedMessage = """
            \(pantryContext)
            \(settingsContext)
            
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

// MARK: - Extensions for safe formatting
extension Double {
    var isValidForUI: Bool {
        return !isNaN && !isInfinite && isFinite
    }
    
    var safeFormattedString: String {
        guard isValidForUI else { return "0" }
        
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(self))
        } else {
            return String(format: "%.1f", self)
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
