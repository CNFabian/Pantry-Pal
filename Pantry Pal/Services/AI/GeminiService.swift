//
//  GeminiService.swift
//  Pantry Pal
//

import Foundation
import GoogleGenerativeAI
import AVFoundation

@MainActor
class GeminiService: ObservableObject {
    private let model: GenerativeModel
    private var chat: Chat?
    
    @Published var isListening = false
    @Published var isProcessing = false
    @Published var currentResponse = ""
    @Published var conversationHistory: [ChatMessage] = []
    
    // Audio recording components
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    init() {
        // Initialize Gemini model with your API key from GoogleService-Info.plist
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["API_KEY"] as? String else {
            fatalError("Could not load API key from GoogleService-Info.plist")
        }
        
        let systemPrompt = ModelContent(parts: [
            .text("""
            You are Pantry Pal, a friendly and bubbly AI assistant for a pantry management app! 🥕✨
            
            Your personality:
            - Cheerful, enthusiastic, and food-obsessed
            - Make occasional food puns and jokes
            - Use food emojis frequently
            - Be encouraging about cooking and food management
            
            Your capabilities:
            - Help users scan barcodes to add items to their pantry
            - Discuss pantry inventory and ingredients
            - Suggest recipes based on available ingredients
            - Talk about food categories, expiration dates, and organization
            - Provide cooking tips and food storage advice
            - Share food-related fun facts
            
            What you CANNOT discuss:
            - Topics unrelated to food, cooking, or pantry management
            - Personal advice outside of food/cooking
            - Politics, controversial topics, or inappropriate content
            
            When users ask about non-food topics, politely redirect them back to food and pantry management with a food joke or pun.
            
            Always be helpful, encouraging, and maintain your bubbly food-focused personality!
            """)
        ])
        
        model = GenerativeModel(
            name: "gemini-1.5-flash",
            apiKey: apiKey,
            systemInstruction: systemPrompt
        )
        
        setupChat()
    }
    
    private func setupChat() {
        chat = model.startChat()
    }
    
    // MARK: - Barcode Integration
    func handleScannedBarcode(_ barcode: String, fatSecretService: FatSecretService) async {
        isProcessing = true
        
        do {
            // First try to get food info from FatSecret
            if let food = try await fatSecretService.searchFoodByBarcode(barcode) {
                let message = """
                Great! I found that barcode! 🎉 It's \(food.food_name)! 
                This looks delicious! Would you like me to help you add this to your pantry? 
                I can suggest the best storage tips for \(food.food_name) too! 🥗✨
                """
                await sendMessage(message, isUser: false)
            } else {
                let message = """
                Oops! I couldn't find that barcode in my food database. 🤔 
                Sometimes barcodes can be tricky - like trying to find the perfect avocado! 🥑
                You can still add items manually to your pantry. What food were you trying to scan?
                """
                await sendMessage(message, isUser: false)
            }
        } catch {
            let message = """
            Hmm, I had trouble scanning that barcode - it's giving me more trouble than opening a pickle jar! 🥒😅
            But don't worry, you can always add items manually. What food item were you looking to add?
            """
            await sendMessage(message, isUser: false)
        }
        
        isProcessing = false
    }
    
    // MARK: - Chat Functions
    func sendMessage(_ text: String, isUser: Bool = true) async {
        let message = ChatMessage(text: text, isUser: isUser, timestamp: Date())
        conversationHistory.append(message)
        
        if isUser {
            isProcessing = true
            
            do {
                let response = try await chat?.sendMessage(text)
                if let responseText = response?.text {
                    currentResponse = responseText
                    let aiMessage = ChatMessage(text: responseText, isUser: false, timestamp: Date())
                    conversationHistory.append(aiMessage)
                }
            } catch {
                let errorMessage = "Oops! I got a bit mixed up there - like confusing salt with sugar! 🧂😅 Could you try asking again?"
                let aiMessage = ChatMessage(text: errorMessage, isUser: false, timestamp: Date())
                conversationHistory.append(aiMessage)
            }
            
            isProcessing = false
        }
    }
    
    // MARK: - Voice Functions
    func startListening() async {
        isListening = true
        // Implementation for voice recording would go here
        // For now, we'll focus on text-based interaction
    }
    
    func stopListening() {
        isListening = false
        // Stop audio recording and process speech-to-text
    }
    
    func clearConversation() {
        conversationHistory.removeAll()
        setupChat() // Reset the chat
    }
}

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
}
