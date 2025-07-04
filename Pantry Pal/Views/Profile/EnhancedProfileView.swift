//
//  EnhancedProfileView.swift
//  Pantry Pal
//

import SwiftUI

struct EnhancedProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Constants.Design.largePadding) {
                    // Profile Header
                    profileHeader
                    
                    // Quick Stats
                    quickStats
                    
                    // Action Buttons
                    actionButtons
                    
                    // Account Settings
                    accountSettings
                    
                    Spacer()
                }
                .padding(.horizontal, Constants.Design.standardPadding)
                .padding(.top, Constants.Design.largePadding)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .themedBackground()
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                SettingsView(settingsType: .general)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSettings = false
                            }
                        }
                    }
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: Constants.Design.standardPadding) {
            // Profile Picture Placeholder
            Circle()
                .fill(Color.primaryOrange.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.primaryOrange)
                )
            
            // User Info
            VStack(spacing: 8) {
                Text(authService.user?.email ?? "User")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Text("Pantry Pal User")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
        }
    }
    
    private var quickStats: some View {
        HStack(spacing: Constants.Design.standardPadding) {
            StatCard(
                title: "Ingredients",
                value: "\(firestoreService.ingredients.count)",
                icon: "leaf.fill",
                color: .green
            )
            
            StatCard(
                title: "Recipes",
                value: "\(firestoreService.recipes.count)",
                icon: "book.fill",
                color: .blue
            )
            
            StatCard(
                title: "Active",
                value: "\(firestoreService.ingredients.filter { !$0.inTrash }.count)",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: Constants.Design.standardPadding) {
            Button(action: {
                showingSettings = true
            }) {
                HStack {
                    Image(systemName: "gear")
                        .font(.title3)
                    Text("Settings")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .foregroundColor(.textPrimary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                        .fill(Color(.systemGray6))
                )
            }
            
            Button(action: {
                // Handle backup/sync
            }) {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.title3)
                    Text("Backup & Sync")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .foregroundColor(.textPrimary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }
    
    private var accountSettings: some View {
        VStack(spacing: Constants.Design.standardPadding) {
            Button(action: {
                authService.signOut()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.title3)
                    Text("Sign Out")
                        .font(.headline)
                    Spacer()
                }
                .foregroundColor(.red)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.Design.standardPadding)
        .background(
            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                .fill(Color(.systemGray6))
        )
    }
}
