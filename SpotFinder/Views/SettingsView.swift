//
//  SettingsView.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var viewModel: LoginViewModel
    @State private var userEmail: String = ""
    @State private var username: String = ""
    @State private var isEditingUsername = false
    @State private var editedUsername: String = ""
    @State private var isSavingUsername = false
    @State private var usernameError: String?
    @State private var showContactSupport = false
    private let userService = UserService()
    
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    // Profile icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account")
                            .font(.headline)
                        if !username.isEmpty {
                            Text("@\(username)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        } else {
                            Text("No username set")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Text(userEmail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                
                if isEditingUsername {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Username", text: $editedUsername)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                        if let error = usernameError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        HStack {
                            Button("Cancel") {
                                isEditingUsername = false
                                editedUsername = username
                                usernameError = nil
                            }
                            .foregroundColor(.secondary)
                            Spacer()
                            Button("Save") {
                                Task { await saveUsername() }
                            }
                            .fontWeight(.semibold)
                            .disabled(editedUsername.isEmpty || isSavingUsername)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Button(action: {
                        editedUsername = username
                        isEditingUsername = true
                        usernameError = nil
                    }) {
                        Label("Edit Username", systemImage: "pencil")
                            .foregroundColor(.blue)
                    }
                }
            } header: {
                Text("Account")
                    .font(.headline)
            }
            
            Section {
                HStack {
                    Label("Version", systemImage: "info.circle.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("App Name", systemImage: "app.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("SpotFinder")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
                    .font(.headline)
            }
            
            Section("Help & Support") {
                Button(action: {
                    showContactSupport = true
                }) {
                    Label("Contact Support", systemImage: "envelope.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            
            Section {
                Button(action: {
                    Task {
                        await viewModel.logout()
                    }
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.right.square.fill")
                        Text("Logout")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundColor(.red)
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showContactSupport) {
            NavigationStack {
                ContactSupportView()
            }
        }
        .onAppear {
            loadUserInfo()
        }
    }
    
    private func loadUserInfo() {
        if let user = Auth.auth().currentUser {
            userEmail = user.email ?? "No email"
        }
        Task {
            if let uid = Auth.auth().currentUser?.uid,
               let profile = try? await userService.getProfile(uid: uid) {
                username = profile.username
            }
        }
    }
    
    private func saveUsername() async {
        guard !editedUsername.isEmpty else { return }
        isSavingUsername = true
        usernameError = nil
        do {
            try await userService.updateUsername(editedUsername)
            username = editedUsername
            isEditingUsername = false
            loadUserInfo()
        } catch {
            usernameError = error.localizedDescription
        }
        isSavingUsername = false
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
    
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(LoginViewModel())
    }
}

