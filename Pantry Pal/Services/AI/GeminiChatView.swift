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
    
    @State private var messageText = ""
    @State private var showingBarcodeScanner = false
    @State private var scannedBarcode: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat messages
                chatMessagesView
                
                // Input area
                inputArea
            }
            .navigationTitle("Pantry Pal AI 🤖")
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
                        
                        Button("View Pantry") {
                            // Navigate to pantry - you'll need to implement this navigation
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
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.primaryOrange)
            
            Text("Hey there, food lover! 🍳")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            Text("I'm your friendly Pantry Pal AI! I can help you scan barcodes, manage your pantry, suggest recipes, and chat about all things food! What's cooking? 👨‍🍳✨")
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Design.standardPadding)
        }
        .padding(.vertical, Constants.Design.largePadding)
    }
    
    private var inputArea: some View {
        VStack(spacing: Constants.Design.smallPadding) {
            Divider()
            
            HStack(spacing: Constants.Design.smallPadding) {
                // Barcode scan button
                Button(action: {
                    showingBarcodeScanner = true
                }) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 20))
                        .foregroundColor(.primaryOrange)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.primaryOrange.opacity(0.1))
                        )
                }
                
                // Text input
                HStack {
                    TextField("Ask me about food, recipes, or your pantry...", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                    
                    if !messageText.isEmpty {
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.primaryOrange)
                        }
                        .disabled(geminiService.isProcessing)
                    }
                }
                .padding(.horizontal, Constants.Design.standardPadding)
                .padding(.vertical, Constants.Design.smallPadding)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                )
            }
            .padding(.horizontal, Constants.Design.standardPadding)
            .padding(.bottom, Constants.Design.smallPadding)
        }
        .background(Color(.systemBackground))
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = messageText
        messageText = ""
        
        Task {
            await geminiService.sendMessage(message)
        }
    }
}
