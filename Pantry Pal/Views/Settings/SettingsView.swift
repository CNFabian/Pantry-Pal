//
//  SettingsView.swift
//  Pantry Pal
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsService: SettingsService
    @Environment(\.dismiss) private var dismiss
    @State private var aiShouldAskForExpirationDates = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI Assistant")) {
                    Toggle("Ask for expiration dates", isOn: $aiShouldAskForExpirationDates)
                    
                    Text("When enabled, the AI will ask for expiration dates when you add ingredients without them. When disabled, the AI will only use expiration dates if you provide them.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await settingsService.updateAIExpirationDateSetting(aiShouldAskForExpirationDates)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            aiShouldAskForExpirationDates = settingsService.userSettings?.aiShouldAskForExpirationDates ?? true
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsService())
}
