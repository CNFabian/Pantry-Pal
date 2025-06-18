//
//  LoginView.swift
//  Pantry Pal
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    
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
                Text("Welcome Back!")
                    .font(.title2)
                    .foregroundColor(.textSecondary)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Form
            VStack(spacing: 16) {
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
                        .textContentType(.password)
                }
            }
            
            // Sign In Button
            Button(action: {
                Task {
                    await authService.signIn(email: email, password: password)
                    if !authService.errorMessage.isEmpty {
                        showingAlert = true
                    }
                }
            }) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.primaryOrange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
            .opacity((authService.isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
            
            Spacer()
            
            // Sign Up Link
            HStack {
                Text("Don't have an account?")
                    .foregroundColor(.textSecondary)
                Button("Sign up here") {
                    NotificationCenter.default.post(name: .showRegister, object: nil)
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
            }
        } message: {
            Text(authService.errorMessage)
        }
    }
}

// Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationService())
}
