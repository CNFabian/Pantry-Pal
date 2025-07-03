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
    @EnvironmentObject var ingredientCache: IngredientCacheService

    
    @State private var showingBarcodeScanner = false
    @State private var scannedBarcode: String?
    @State private var messageText = ""
    
    let ingredients = ingredientCache.getIngredients()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Error state check
                if case .error(_) = geminiService.connectionStatus {
                    errorStateView
                } else {
                    // Status bar
                    statusBar
                    
                    // Chat messages
                    chatMessagesView
                    
                    // Voice and input controls
                    inputControlsArea
                }
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
                geminiService.configure(firestoreService: firestoreService, authService: authService)
            } 
        }
        
    }
    
    private var errorStateView: some View {
        VStack(spacing: Constants.Design.standardPadding) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("AI Assistant Unavailable")
                .font(.title2)
                .fontWeight(.bold)
            
            if case .error(let message) = geminiService.connectionStatus {
                Text(message)
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Retry") {
                geminiService.clearConversation()
            }
            .buttonStyle(.borderedProminent)
            .tint(.primaryOrange)
        }
        .padding(Constants.Design.largePadding)
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
            
            Text("Hey there, food lover!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            Text("I'm your AI pantry assistant! 🍽️\nAsk me about recipes, ingredients, or just chat about food!")
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            
            VStack(spacing: Constants.Design.smallPadding) {
                Text("Try saying:")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• \"What can I cook with chicken and rice?\"")
                    Text("• \"How long do tomatoes last?\"")
                    Text("• \"Suggest a healthy breakfast\"")
                }
                .font(.caption)
                .foregroundColor(.textSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                    .fill(Color(.systemGray6))
            )
        }
        .padding(Constants.Design.standardPadding)
    }
    
    private var inputControlsArea: some View {
        VStack(spacing: Constants.Design.smallPadding) {
            // Voice button
            voiceButton
            
            // Text input
            textInputArea
        }
        .padding(Constants.Design.standardPadding)
        .background(Color(.systemBackground))
    }
    
    private var voiceButton: some View {
        Button {
            if geminiService.isListening {
                geminiService.stopListening()
            } else {
                geminiService.startListening()
            }
        } label: {
            Image(systemName: geminiService.isListening ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(geminiService.isListening ? .red : .primaryOrange)
        }
        .disabled(geminiService.isProcessing || geminiService.isSpeaking)
        .scaleEffect(geminiService.isListening ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: geminiService.isListening)
    }
    
    private var textInputArea: some View {
        HStack {
            TextField("Type a message...", text: $messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    sendTextMessage()
                }
            
            Button {
                sendTextMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(.primaryOrange)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || geminiService.isProcessing)
        }
    }
    
    private func sendTextMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        messageText = ""
        Task {
            await geminiService.sendMessage(text)
        }
    }
}

// Add these extensions at the very end of the file, outside of any struct
extension Double {
    var isValidForUI: Bool {
        return !isNaN && !isInfinite && isFinite
    }
    
    var safeForUI: Double {
        return isValidForUI ? self : 0.0
    }
}

extension CGFloat {
    var isValidForUI: Bool {
        return !isNaN && !isInfinite && isFinite
    }
    
    var safeForUI: CGFloat {
        return isValidForUI ? self : 0.0
    }
}

#Preview {
    GeminiChatView()
        .environmentObject(FatSecretService())
        .environmentObject(FirestoreService())
        .environmentObject(AuthenticationService())
}
