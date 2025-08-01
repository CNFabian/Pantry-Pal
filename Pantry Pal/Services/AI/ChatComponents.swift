//
//  ChatComponents.swift
//  Pantry Pal
//

import SwiftUI

struct ChatBubble: View {
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
                .padding(.leading, 44) // Align with message text
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TypingIndicator: View {
    @State private var animateOpacity = false
    
    var body: some View {
        HStack {
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
                            .frame(width: 6, height: 6)
                            .opacity(animateOpacity ? 0.3 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: animateOpacity
                            )
                    }
                }
                .padding(.horizontal, Constants.Design.standardPadding)
                .padding(.vertical, Constants.Design.smallPadding)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemGray6))
                )
            }
            
            Spacer(minLength: 60)
        }
        .onAppear {
            animateOpacity.toggle()
        }
    }
}
