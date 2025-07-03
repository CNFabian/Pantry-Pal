//
//  AuthenticationView.swift
//  Pantry Pal
//

import SwiftUI

struct AuthenticationView: View {
    @State private var showingRegister = false
    
    var body: some View {
        ZStack {
            if showingRegister {
                RegisterView()
                    .transition(.slide)
            } else {
                LoginView()
                    .transition(.slide)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showRegister)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingRegister = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showLogin)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingRegister = false
            }
        }
    }
}

// Add these notification names
extension Notification.Name {
    static let showRegister = Notification.Name("showRegister")
    static let showLogin = Notification.Name("showLogin")
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationService())
}
