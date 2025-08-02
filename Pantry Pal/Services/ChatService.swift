import Foundation

class ChatService {
    private let apiKey = "YOUR_OPENAI_API_KEY" // Replace with your actual API key
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    
    func sendMessage(_ message: String) async throws -> String {
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are PantryPal, a friendly AI assistant that helps users manage their pantry, find recipes, and reduce food waste."],
                ["role": "user", "content": message]
            ],
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        
        throw NSError(domain: "ChatService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
    }
}//
//  ChatService.swift
//  Pantry Pal
//
//  Created by Christopher Fabian on 8/1/25.
//

