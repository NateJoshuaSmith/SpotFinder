import SwiftUI
import Combine

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoggedIn = false
    @Published var needsUsernameSetup = false  // For existing users without a profile
    
    private let authService = AuthService()
    private let userService = UserService()

    func login(email: String, password: String) async {
        do {
            try await authService.signIn(email: email, password: password)
            if let uid = authService.currentUserId {
                let hasProfile = await userService.hasProfile(uid: uid)
                if !hasProfile {
                    needsUsernameSetup = true
                }
            }
            isLoggedIn = true
            if let email = authService.currentUserEmail {
                print("Logged in as: \(email)")
            }
        } catch {
            print("Error signing in: \(error)")
        }
    }

    func signUp(email: String, password: String, username: String) async throws {
        do {
            try await authService.signUp(email: email, password: password)
            if let uid = authService.currentUserId {
                try await userService.createProfile(uid: uid, username: username, email: email)
            }
            isLoggedIn = true
            print("Sign up successful!")
        } catch {
            print("Error signing up: \(error)")
            throw error
        }
    }
    
    func completeUsernameSetup(username: String) async throws {
        guard let uid = authService.currentUserId else { return }
        try await userService.createProfile(uid: uid, username: username, email: authService.currentUserEmail)
        needsUsernameSetup = false
    }
    
    func logout() async {
        do {
            try authService.signOut()
            print("Logout successful!")
            isLoggedIn = false
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
