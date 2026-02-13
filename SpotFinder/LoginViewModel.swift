import SwiftUI
import Combine
import FirebaseAuth

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoggedIn = false

    func login(email: String, password: String) async {
        let auth = Auth.auth()
        do {
            try await auth.signIn(withEmail: email, password: password)
            print("Login successful!")
            isLoggedIn = true
            if let user = auth.currentUser {
                print("Logged in as: \(user.email ?? "unknown")")
            }
        } catch {
            print("Error signing in: \(error)")
        }
    }

    func signUp(email: String, password: String) async {
        let auth = Auth.auth()
        do {
            try await auth.createUser(withEmail: email, password: password)
            print("Sign up successful!")
            isLoggedIn = true
        } catch {
            print("Error signing up: \(error)")
        }
    }
    
    func logout() async {
        let auth = Auth.auth()
        do {
            try auth.signOut()
            print("Logout successful!")
            isLoggedIn = false
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
