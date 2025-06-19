//
//  AuthenticationService.swift
//  Pantry Pal
//

import Foundation
import Firebase
import FirebaseAuth
import Combine

class AuthenticationService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        listenToAuthState()
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    func listenToAuthState() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            print("🐛 DEBUG: Auth state changed")
            print("🐛 DEBUG: Firebase user: \(String(describing: user))")
            print("🐛 DEBUG: User UID: \(user?.uid ?? "nil")")
            
            DispatchQueue.main.async {
                self?.isAuthenticated = user != nil
                if let user = user {
                    print("🐛 DEBUG: User authenticated, fetching user data")
                    Task {
                        await self?.fetchUserData(uid: user.uid)
                    }
                } else {
                    print("🐛 DEBUG: No user, setting to nil")
                    self?.user = nil
                }
            }
        }
    }
    
    // MARK: - Authentication Methods
    func signIn(email: String, password: String) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = ""
        }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await fetchUserData(uid: result.user.uid)
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = self.handleAuthError(error)
                self.isLoading = false
            }
        }
    }
    
    func signUp(email: String, password: String, displayName: String) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = ""
        }
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Update profile with display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            
            // Create user document in Firestore
            await createUserDocument(uid: result.user.uid, email: email, displayName: displayName)
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = self.handleAuthError(error)
                self.isLoading = false
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.user = nil
                self.isAuthenticated = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to sign out"
            }
        }
    }
    
    func resetPassword(email: String) async {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = self.handleAuthError(error)
            }
        }
    }
    
    // MARK: - Firestore User Operations
    private func createUserDocument(uid: String, email: String, displayName: String) async {
        let userData = User(
            id: uid,
            email: email,
            displayName: displayName,
            photoURL: nil,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
        
        do {
            try Firestore.firestore()
                .collection(Constants.Firebase.users)
                .document(uid)
                .setData(from: userData)
            
            DispatchQueue.main.async {
                self.user = userData
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create user profile"
                self.isLoading = false
            }
        }
    }
    
    private func createUserDocumentFromFirebaseAuth(uid: String) async {
        guard let firebaseUser = Auth.auth().currentUser else {
            print("🐛 DEBUG: No Firebase user available")
            DispatchQueue.main.async {
                self.errorMessage = "Authentication error"
                self.isLoading = false
            }
            return
        }
        
        print("🐛 DEBUG: Creating user document for UID: \(uid)")
        
        let userData = User(
            id: uid,
            email: firebaseUser.email ?? "",
            displayName: firebaseUser.displayName ?? "User",
            photoURL: firebaseUser.photoURL?.absoluteString,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
        
        do {
            try await Firestore.firestore()
                .collection(Constants.Firebase.users)
                .document(uid)
                .setData(from: userData)
            
            print("🐛 DEBUG: Created user document successfully")
            
            DispatchQueue.main.async {
                self.user = userData
                self.isLoading = false
            }
        } catch {
            print("🐛 DEBUG: Failed to create user document: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create user profile"
                self.isLoading = false
            }
        }
    }
    
    func ensureUserReady() async -> Bool {
        print("🐛 DEBUG: Ensuring user is ready")
        
        guard let firebaseUser = Auth.auth().currentUser else {
            print("🐛 DEBUG: No Firebase user in ensureUserReady")
            return false
        }
        
        print("🐛 DEBUG: Firebase user exists: \(firebaseUser.uid)")
        
        // If we already have user data, return true
        if let user = self.user {
            print("🐛 DEBUG: User data already exists: \(user.id ?? "no-id")")
            return true
        }
        
        // Try to fetch user data
        print("🐛 DEBUG: Fetching user data...")
        await fetchUserData(uid: firebaseUser.uid)
        
        // Check if we now have user data
        let hasUser = self.user != nil
        print("🐛 DEBUG: User ready status: \(hasUser)")
        return hasUser
    }
    
    private func fetchUserData(uid: String) async {
        print("🐛 DEBUG: Fetching user data for UID: \(uid)")
        do {
            let document = try await Firestore.firestore()
                .collection(Constants.Firebase.users)
                .document(uid)
                .getDocument()
            
            print("🐛 DEBUG: User document exists: \(document.exists)")
            
            if let userData = try? document.data(as: User.self) {
                print("🐛 DEBUG: Successfully decoded user data: \(userData)")
                DispatchQueue.main.async {
                    self.user = userData
                    self.isLoading = false
                }
            } else {
                print("🐛 DEBUG: Failed to decode user data, creating new user document")
                // If user document doesn't exist, create it
                await createUserDocumentFromFirebaseAuth(uid: uid)
            }
        } catch {
            print("🐛 DEBUG: Error fetching user data: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load user data"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Error Handling
    private func handleAuthError(_ error: Error) -> String {
        guard let authError = error as? AuthErrorCode else {
            return error.localizedDescription
        }
        
        switch authError.code {
        case .userNotFound:
            return "No account found with this email address."
        case .wrongPassword:
            return "Incorrect password."
        case .invalidEmail:
            return "Invalid email address."
        case .userDisabled:
            return "This account has been disabled."
        case .tooManyRequests:
            return "Too many failed attempts. Please try again later."
        case .emailAlreadyInUse:
            return "An account with this email address already exists."
        case .weakPassword:
            return "Password is too weak. Please choose a stronger password."
        default:
            return "An error occurred. Please try again."
        }
    }
}
