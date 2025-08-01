//
//  OpenAIChatView.swift
//  Pantry Pal
//

import SwiftUI

struct OpenAIChatView: View {
    @StateObject private var openAIService = OpenAIService()
    @EnvironmentObject var fatSecretService: FatSecretService
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var ingredientCache: IngredientCacheService
    @EnvironmentObject private var settingsService: SettingsService

    @State private var showSettings = false
    @State private var showingBarcodeScanner = false
    @State private var scannedBarcode: String?
    @State private var messageText = ""
    
    private var ingredients: [Ingredient] {
        ingredientCache.getIngredients()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Error state check
                if case .error(_) = openAIService.connectionStatus {
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
                        Button("Clear Chat") {
                            clearConversation()
                        }
                        
                        Button(openAIService.isSpeaking ? "Stop Speaking" : "Settings") {
                            if openAIService.isSpeaking {
                                openAIService.stopSpeaking()
                            } else {
                                showSettings = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primaryOrange)
                    }
                }
            }
        }
        .onAppear {
            openAIService.configure(firestoreService: firestoreService, authService: authService)
            openAIService.setSettingsService(settingsService)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    private var errorStateView: some View {
        VStack(spacing: Constants.Design.standardPadding) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Connection Error")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            if case .error(let message) = openAIService.connectionStatus {
                Text(message)
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Retry") {
                clearConversation()
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
            
            if openAIService.isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
            }
            
            if !openAIService.speechRecognitionText.isEmpty && openAIService.isListening {
                Text("Listening: \(openAIService.speechRecognitionText)")
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
        switch openAIService.connectionStatus {
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
        switch openAIService.connectionStatus {
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
                    if openAIService.conversationHistory.isEmpty {
                        welcomeMessage
                    }
                    
                    // Chat messages
                    ForEach(openAIService.conversationHistory) { message in
                        PantryChatBubble(message: message)
                    }
                    
                    // Typing indicator
                    if openAIService.isProcessing {
                        TypingIndicator()
                    }
                }
                .padding(.horizontal, Constants.Design.standardPadding)
                .padding(.vertical, Constants.Design.smallPadding)
            }
            .onChange(of: openAIService.conversationHistory.count) { _, _ in
                if let lastMessage = openAIService.conversationHistory.last {
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
            toggleListening()
        } label: {
            Image(systemName: openAIService.isListening ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(openAIService.isListening ? .red : .primaryOrange)
        }
        .disabled(openAIService.isProcessing || openAIService.isSpeaking)
        .scaleEffect(openAIService.isListening ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: openAIService.isListening)
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
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || openAIService.isProcessing)
        }
    }
    
    // MARK: - Actions
    private func sendTextMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        messageText = ""
        Task {
            await openAIService.sendMessage(text)
        }
    }
    
    private func toggleListening() {
        if openAIService.isListening {
            openAIService.stopListening()
        } else {
            openAIService.startListening()
        }
    }
    
    private func clearConversation() {
        openAIService.conversationHistory.removeAll()
        openAIService.stopSpeaking()
        openAIService.stopListening()
        openAIService.connectionStatus = .ready
    }
}

// MARK: - Custom Chat Bubble for PantryChatMessage
struct PantryChatBubble: View {
    let message: PantryChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
                userBubble
            } else {
                aiBubble
                Spacer(minLength: 60)
            }
        }
    }
    
    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.text)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, Constants.Design.standardPadding)
                .padding(.vertical, Constants.Design.smallPadding)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.primaryOrange)
                )
            
            Text(formatTime(message.timestamp))
                .font(.caption2)
                .foregroundColor(.textSecondary)
                .padding(.trailing, 4)
        }
    }
    
    private var aiBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: Constants.Design.smallPadding) {
                // AI Avatar
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.primaryOrange)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.primaryOrange.opacity(0.1))
                    )
                
                Text(message.text)
                    .font(.body)
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, Constants.Design.standardPadding)
                    .padding(.vertical, Constants.Design.smallPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.systemGray6))
                    )
            }
            
            Text(formatTime(message.timestamp))
                .font(.caption2)
                .foregroundColor(.textSecondary)
                .padding(.leading, 44)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
