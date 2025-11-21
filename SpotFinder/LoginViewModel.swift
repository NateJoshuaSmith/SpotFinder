import SwiftUI
import Combine
import FirebaseAuth

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""

    func login(email: String, password: String) async {
        let auth = Auth.auth()
        do {
            try await auth.signIn(withEmail: email, password: password)
            print("Login successful!")
            if let user = auth.currentUser {
                print("Logged in as: \(user.email ?? "unknown")")
            }
        } catch {
            print("Error signing in: \(error)")
        }
    }

// old login function not needed anymore because firebase auth is used instead
    func oldLogin(email: String, password: String) {

        if email == "" || password == "" {
            print("Email and password are required")
            return
        }

        if password.count < 8 {
            print("Password must be at least 8 characters long")
            return
        }

        if !email.contains("@") || !email.contains(".") || !email.contains(" ") {
            print("Email must contain @ and a .")
            return
        }
    }
}
