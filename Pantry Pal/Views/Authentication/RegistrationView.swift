//
//  RegisterView.swift
//  Pantry Pal
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // Logo/Header
            VStack(spacing: 8) {
                Text("🥕")
                    .font(.system(size: 60))
                Text("Pantry Pal")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryOrange)
                Text("Create Account")
                    .font(.title2)
                    .foregroundColor(.textSecondary)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Form
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    TextField("Enter your name", text: $name)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.name)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.newPassword)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    SecureField("Confirm your password", text: $confirmPassword)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.newPassword)
                }
            }
            
            // Sign Up Button
            Button(action: {
                validateAndSignUp()
            }) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.primaryOrange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authService.isLoading || !isFormValid)
            .opacity((authService.isLoading || !isFormValid) ? 0.6 : 1.0)
            
            Spacer()
            
            // Sign In Link
            HStack {
                Text("Already have an account?")
                    .foregroundColor(.textSecondary)
                Button("Sign in here") {
                    NotificationCenter.default.post(name: .showLogin, object: nil)
                }
                .foregroundColor(.primaryOrange)
                .fontWeight(.medium)
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
        .themedBackground()
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") {
                authService.errorMessage = ""
                alertMessage = ""
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
    }
    
    private func validateAndSignUp() {
        // Reset any previous errors
        alertMessage = ""
        authService.errorMessage = ""
        
        // Validate name
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            alertMessage = "Please enter your name."
            showingAlert = true
            return
        }
        
        // Validate email
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            alertMessage = "Please enter your email address."
            showingAlert = true
            return
        }
        
        // Validate password length
        if password.count < 6 {
            alertMessage = "Password must be at least 6 characters long."
            showingAlert = true
            return
        }
        
        // Validate password match
        if password != confirmPassword {
            alertMessage = "Passwords do not match."
            showingAlert = true
            return
        }
        
        // If all validation passes, attempt sign up
        Task {
            await authService.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                displayName: name.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            if !authService.errorMessage.isEmpty {
                alertMessage = authService.errorMessage
                showingAlert = true
            }
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthenticationService())
}
