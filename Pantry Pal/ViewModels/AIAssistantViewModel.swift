import Foundation
import Combine
import AVFoundation

class AIAssistantViewModel: ObservableObject {
    @Published var isSpeaking = false
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var responseText = ""
    
    private var speechRecognizer = SpeechRecognizer()
    private var chatService = ChatService()
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        speechRecognizer.$transcribedText
            .sink { [weak self] text in
                self?.transcribedText = text
                if !text.isEmpty && !(self?.speechRecognizer.isRecording ?? false) {
                    self?.sendMessage(text)
                }
            }
            .store(in: &cancellables)
    }
    
    func startListening() {
        isListening = true
        speechRecognizer.startRecording()
        
        // Stop after 5 seconds of recording
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.stopListening()
        }
    }
    
    func stopListening() {
        isListening = false
        speechRecognizer.stopRecording()
    }
    
    private func sendMessage(_ message: String) {
        Task {
            do {
                isSpeaking = true
                let response = try await chatService.sendMessage(message)
                responseText = response
                speak(response)
            } catch {
                print("Error sending message: \(error)")
                isSpeaking = false
            }
        }
    }
    
    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        speechSynthesizer.speak(utterance)
        
        // Simulate speaking duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.isSpeaking = false
        }
    }
}//
//  AIAssistantViewModel.swift
//  Pantry Pal
//
//  Created by Christopher Fabian on 8/1/25.
//

