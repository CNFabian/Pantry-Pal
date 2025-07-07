//
//  LiveSession.swift
//  Pantry Pal
//

import Foundation
import GoogleGenerativeAI

// Live API response types
enum LiveResponseType {
    case text
    case audio
    case error
}

struct LiveResponse {
    let type: LiveResponseType
    let text: String?
    let audioData: Data?
    let error: Error?
}

// Live session wrapper (this would be implemented based on the actual Live API)
class LiveSession {
    var onResponse: ((LiveResponse) -> Void)?
    
    init() {
        // Initialize live session connection
    }
    
    func sendMessage(_ text: String) async throws {
        // Send message to live API
    }
    
    func end() {
        // End live session
    }
}

// Extension for GenerativeModel to support Live API
extension GenerativeModel {
    func startLiveSession() async throws -> LiveSession {
        // This would create a live session with the Gemini Live API
        return LiveSession()
    }
}
