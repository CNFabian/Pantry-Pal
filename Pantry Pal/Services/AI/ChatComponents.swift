//
//  ChatComponents.swift
//  Pantry Pal
//

import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    
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
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TypingIndicator: View {
    @State private var animationPhase = 0
    
    var body: some View {
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
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.textSecondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .opacity(animationPhase == index ? 1.0 : 0.6)
                }
            }
            .padding(.horizontal, Constants.Design.standardPadding)
            .padding(.vertical, Constants.Design.smallPadding)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemGray6))
            )
            
            Spacer(minLength: 60)
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}
