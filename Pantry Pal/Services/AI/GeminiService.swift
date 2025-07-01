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
            - Help users manage their pantry ingredients
            - Suggest recipes based on available ingredients
            - Answer cooking and food storage questions
            - Give meal planning advice
            - Help with grocery shopping suggestions
            - Provide food safety information
            
            Keep responses conversational, helpful, and under 100 words when possible. Always be encouraging about cooking adventures!
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
        // Check if TTS is available
        guard !text.isEmpty else { return }
        
        stopSpeaking() // Stop any current speech
        
        // Check if speech synthesis voices are available
        guard !AVSpeechSynthesisVoice.speechVoices().isEmpty else {
            print("⚠️ TTS not available, continuing without speech")
            connectionStatus = .ready
            return
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Try to get a voice, fallback to default if needed
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        } else {
            print("⚠️ en-US voice not available, using default")
            utterance.voice = AVSpeechSynthesisVoice.speechVoices().first
        }
        
        utterance.rate = Float(AVSpeechUtteranceDefaultSpeechRate * 1.1)
        utterance.pitchMultiplier = Float(1.1)
        
        do {
            isSpeaking = true
            connectionStatus = .speaking
            speechSynthesizer.speak(utterance)
        } catch {
            print("⚠️ TTS failed: \(error.localizedDescription)")
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
    func sendMessage(_ text: String, isUser: Bool = true) async {
        let message = ChatMessage(text: text, isUser: isUser, timestamp: Date())
        conversationHistory.append(message)
        
        if isUser {
            connectionStatus = .processingRequest
            isProcessing = true
            
            do {
                let response = try await chat?.sendMessage(text)
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
