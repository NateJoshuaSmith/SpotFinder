//
//  ContactSupportView.swift
//  SpotFinder
//
//  Change supportEmail to your actual support address.
//

import SwiftUI

struct ContactSupportView: View {
    private let authService = AuthService()
    // Change this to your support email address
    private let supportEmail = "support@yourapp.com"
    
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var username: String = ""
    
    private let userService = UserService()
    
    var body: some View {
        Form {
            Section {
                TextField("Subject", text: $subject)
                TextField("Describe your issue...", text: $message, axis: .vertical)
                    .lineLimit(5...15)
            } header: {
                Text("Message")
            } footer: {
                Text("Your message will open in your email app. App version and username are included to help us assist you.")
            }
            
            Section {
                Button(action: openMail) {
                    HStack {
                        Spacer()
                        Image(systemName: "envelope.fill")
                        Text("Open in Mail")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                
                Button(action: copyEmail) {
                    HStack {
                        Spacer()
                        Image(systemName: "doc.on.doc.fill")
                        Text("Copy Support Email")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadUsername()
        }
    }
    
    private func loadUsername() {
        Task {
            if let uid = authService.currentUserId,
               let profile = try? await userService.getProfile(uid: uid) {
                username = profile.username
            }
        }
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
    
    private func buildEmailBody() -> String {
        var lines: [String] = []
        lines.append("---")
        lines.append("SpotFinder \(appVersion)")
        if !username.isEmpty {
            lines.append("Username: @\(username)")
        }
        lines.append("---")
        lines.append("")
        lines.append(message)
        return lines.joined(separator: "\n")
    }
    
    private func openMail() {
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bodyEncoded = buildEmailBody().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailto = "mailto:\(supportEmail)?subject=\(subjectEncoded)&body=\(bodyEncoded)"
        
        if let url = URL(string: mailto) {
            UIApplication.shared.open(url)
        }
    }
    
    private func copyEmail() {
        UIPasteboard.general.string = supportEmail
    }
}

#Preview {
    NavigationView {
        ContactSupportView()
    }
}
