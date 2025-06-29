//
//  GeminiChatView.swift
//  Pantry Pal
//

import SwiftUI

struct GeminiChatView: View {
    @StateObject private var geminiService = GeminiService()
    @EnvironmentObject var fatSecretService: FatSecretService
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var showingBarcodeScanner = false
    @State private var scannedBarcode: String?
    @State private var messageText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status bar
                statusBar
                
                // Chat messages
                chatMessagesView
                
                // Voice and input controls
                inputControlsArea
            }
            .navigationTitle("Pantry Pal AI 🎙️")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Scan Barcode") {
                            showingBarcodeScanner = true
                        }
                        
                        Button("Clear Chat") {
                            geminiService.clearConversation()
                        }
                        
                        Button(geminiService.isSpeaking ? "Stop Speaking" : "Start Speaking") {
                            if geminiService.isSpeaking {
                                geminiService.stopSpeaking()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primaryOrange)
                    }
                }
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView(scannedCode: $scannedBarcode, isPresented: $showingBarcodeScanner)
            }
            .onChange(of: scannedBarcode) { _, newBarcode in
                if let barcode = newBarcode {
                    Task {
                        await geminiService.handleScannedBarcode(barcode, fatSecretService: fatSecretService)
                    }
                    scannedBarcode = nil
                }
            }
            .onAppear {
                // Set the firestoreService reference
                geminiService.firestoreService = firestoreService
            }

        }
    }
    
    private var statusBar: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.textSecondary)
            
            Spacer()
            
            if geminiService.isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
            }
            
            if !geminiService.speechRecognitionText.isEmpty && geminiService.isListening {
                Text("Listening: \(geminiService.speechRecognitionText)")
                    .font(.caption)
                    .foregroundColor(.primaryOrange)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Constants.Design.standardPadding)
        .padding(.vertical, Constants.Design.smallPadding)
        .background(Color(.systemGray6))
    }
    
    private var statusColor: Color {
        switch geminiService.connectionStatus {
        case .ready:
            return .green
        case .listeningForSpeech:
            return .blue
        case .processingRequest:
            return .orange
        case .speaking:
            return .purple
        case .error(_):
            return .red
        }
    }
    
    private var statusText: String {
        switch geminiService.connectionStatus {
        case .ready:
            return "Ready to chat"
        case .listeningForSpeech:
            return "Listening..."
        case .processingRequest:
            return "Thinking..."
        case .speaking:
            return "Speaking..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Constants.Design.standardPadding) {
                    // Welcome message
                    if geminiService.conversationHistory.isEmpty {
                        welcomeMessage
                    }
                    
                    // Chat messages
                    ForEach(geminiService.conversationHistory) { message in
                        ChatBubble(message: message)
                    }
                    
                    // Typing indicator
                    if geminiService.isProcessing {
                        TypingIndicator()
                    }
                }
                .padding(.horizontal, Constants.Design.standardPadding)
                .padding(.vertical, Constants.Design.smallPadding)
            }
            .onChange(of: geminiService.conversationHistory.count) { _, _ in
                if let lastMessage = geminiService.conversationHistory.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var welcomeMessage: some View {
        VStack(spacing: Constants.Design.standardPadding) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.primaryOrange)
            
            Text("Hey there, food lover! 🎙️")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            Text("I'm your voice-activated Pantry Pal! Hold the mic button to talk with me about food, recipes, barcode scanning, and your pantry. I can also respond to text messages!")
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Design.standardPadding)
        }
        .padding(.vertical, Constants.Design.largePadding)
    }
    
    private var inputControlsArea: some View {
        VStack(spacing: Constants.Design.standardPadding) {
            Divider()
            
            // Voice controls
            HStack(spacing: Constants.Design.largePadding) {
                // Barcode scan button
                Button(action: {
                    showingBarcodeScanner = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 24))
                        Text("Scan")
                            .font(.caption)
                    }
                    .foregroundColor(.primaryOrange)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(Color.primaryOrange.opacity(0.1))
                    )
                }
                
                // Voice control button
                Button(action: {}) {
                    Image(systemName: geminiService.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .fill(geminiService.isListening ? Color.red : Color.primaryOrange)
                                .scaleEffect(geminiService.isListening ? 1.1 : 1.0)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .animation(.easeInOut(duration: 0.2), value: geminiService.isListening)
                }
                .onLongPressGesture(
                    minimumDuration: 0,
                    maximumDistance: .infinity,
                    perform: {},
                    onPressingChanged: { pressing in
                        if pressing {
                            Task { await geminiService.startListening() }
                        } else {
                            geminiService.stopListening()
                        }
                    }
                )
                
                // Stop speaking button
                Button(action: {
                    geminiService.stopSpeaking()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: geminiService.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 24))
                        Text(geminiService.isSpeaking ? "Stop" : "Speaker")
                            .font(.caption)
                    }
                    .foregroundColor(geminiService.isSpeaking ? .red : .textSecondary)
                    .frame(width: 60, height: 60)
                }
            }
            
            // Text input (alternative to voice)
            HStack(spacing: Constants.Design.smallPadding) {
                TextField("Or type your message here...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .padding(.horizontal, Constants.Design.standardPadding)
                    .padding(.vertical, Constants.Design.smallPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                    )
                
                if !messageText.isEmpty {
                    Button(action: sendTextMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.primaryOrange)
                            .font(.system(size: 20))
                    }
                    .disabled(geminiService.isProcessing)
                }
            }
            .padding(.horizontal, Constants.Design.standardPadding)
            .padding(.bottom, Constants.Design.smallPadding)
        }
        .background(Color(.systemBackground))
    }
    
    private func sendTextMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = messageText
        messageText = ""
        
        Task {
            await geminiService.sendMessage(message)
        }
    }
}
