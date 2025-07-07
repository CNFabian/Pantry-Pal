//
//  GeminiService.swift
//  Pantry Pal
//

import Foundation
import GoogleGenerativeAI
import AVFoundation
import Speech

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

@MainActor
class GeminiService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var conversationHistory: [ChatMessage] = []
    @Published var connectionStatus: ConnectionStatus = .ready
    @Published var isProcessing = false
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var speechRecognitionText = ""
    
    // MARK: - Private Properties
    private let model: GenerativeModel
    private var chat: Chat?
    
    // Speech Recognition - keep as MainActor isolated
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Text-to-Speech
    private let synthesizer = AVSpeechSynthesizer()
    
    // Services
    private weak var firestoreService: FirestoreService?
    private weak var authService: AuthenticationService?
    private weak var settingsService: SettingsService?
    
    override init() {
        // Get API key from GoogleService-Info.plist
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["GEMINI_API_KEY"] as? String else {
            fatalError("Couldn't find GEMINI_API_KEY in GoogleService-Info.plist")
        }
        
        // Configure for conversational AI
        let config = GenerationConfig(
            temperature: 0.8,
            topP: 0.9,
            topK: 20,
            maxOutputTokens: 1024
        )
        
        self.model = GenerativeModel(
            name: "gemini-1.5-flash", // Use regular model for now
            apiKey: apiKey,
            generationConfig: config,
            systemInstruction: """
            You are Pantry Pal, a friendly AI assistant that helps users manage their pantry and discover recipes.
            
            Your personality:
            - Enthusiastic about food and cooking
            - Helpful and encouraging
            - Knowledgeable about ingredients and recipes
            - Conversational and friendly
            - Uses food-related emojis appropriately
            
            Your capabilities:
            - Help users understand their pantry ingredients
            - Suggest ways to use ingredients before they expire
            - Provide cooking tips and techniques
            - Answer questions about food storage and preparation
            - Engage in friendly conversation about food and cooking
            
            Keep responses concise but helpful. Always be encouraging about cooking and trying new recipes.
            """
        )
        
        super.init()
        setupServices()
        print("✅ GeminiService initialized with conversational AI model")
    }
    
    // MARK: - Configuration
    func configure(firestoreService: FirestoreService, authService: AuthenticationService) {
        self.firestoreService = firestoreService
        self.authService = authService
        setupChat()
    }
    
    func setSettingsService(_ settingsService: SettingsService) {
        self.settingsService = settingsService
    }
    
    // MARK: - Chat Management
    private func setupChat() {
        chat = model.startChat()
        print("✅ Chat initialized")
    }
    
    func clearConversation() {
        conversationHistory.removeAll()
        setupChat()
    }
    
    // MARK: - Message Handling
    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let userMessage = ChatMessage(text: text, isUser: true)
        conversationHistory.append(userMessage)
        
        isProcessing = true
        connectionStatus = .processingRequest
        
        do {
            guard let chat = chat else {
                setupChat()
                return
            }
            
            let response = try await chat.sendMessage(text)
            
            if let responseText = response.text {
                let aiMessage = ChatMessage(text: responseText, isUser: false)
                conversationHistory.append(aiMessage)
                
                // Optionally speak the response
                if shouldSpeakResponses() {
                    speakText(responseText)
                }
            }
            
            connectionStatus = .ready
        } catch {
            print("❌ Error sending message: \(error)")
            connectionStatus = .error("Failed to send message")
        }
        
        isProcessing = false
    }
    
    private func shouldSpeakResponses() -> Bool {
        // For now, return false. This can be controlled by a user setting later
        return false
    }
    
    // MARK: - Speech Recognition (for voice input)
    func startListening() {
        guard speechRecognizer?.isAvailable == true else {
            connectionStatus = .error("Speech recognition not available")
            return
        }
        
        stopListening()
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let result = result {
                        self?.speechRecognitionText = result.bestTranscription.formattedString
                        
                        if result.isFinal {
                            self?.stopListening()
                            Task {
                                await self?.sendMessage(result.bestTranscription.formattedString)
                            }
                        }
                    }
                    
                    if let error = error {
                        print("❌ Speech recognition error: \(error)")
                        self?.stopListening()
                    }
                }
            }
            
            let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
            audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isListening = true
            connectionStatus = .listeningForSpeech
            speechRecognitionText = ""
            
        } catch {
            print("❌ Failed to start speech recognition: \(error)")
            connectionStatus = .error("Failed to start speech recognition")
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
        speechRecognitionText = ""
        
        if connectionStatus == .listeningForSpeech {
            connectionStatus = .ready
        }
    }
    
    // MARK: - Text-to-Speech
    private func speakText(_ text: String) {
        guard !isSpeaking else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isSpeaking = true
        connectionStatus = .speaking
        
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        connectionStatus = .ready
    }
    
    // MARK: - Setup
    private func setupServices() {
        synthesizer.delegate = self
        
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("✅ Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("❌ Speech recognition not authorized")
                @unknown default:
                    print("❌ Unknown speech recognition status")
                }
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        // Clean up audio resources without MainActor requirements
        // The audio engine and synthesizer can be stopped from any context
        audioEngine.stop()
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        synthesizer.stopSpeaking(at: .immediate)
        
        // Note: recognitionRequest and recognitionTask cleanup happens automatically
        // when the object is deallocated, but we can't access them here due to MainActor isolation
        print("🧹 GeminiService cleanup completed")
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension GeminiService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            if self.connectionStatus == .speaking {
                self.connectionStatus = .ready
            }
        }
    }
}

// MARK: - ChatMessage Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}
