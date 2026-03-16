//
//  SettingsView.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI
import FirebaseAuth
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: LoginViewModel
    @StateObject private var userService = UserService()
    @State private var userEmail: String = ""
    @State private var currentUsername: String?
    @State private var avatarURL: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var showContactSupport = false
    @State private var showChangeUsername = false
    
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Group {
                            if let urlString = avatarURL, let url = URL(string: urlString) {
                                ZStack {
                                    // Always show placeholder underneath to avoid a blank flash
                                    avatarPlaceholder
                                    AsyncImage(
                                        url: url,
                                        transaction: Transaction(animation: .easeInOut)
                                    ) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .transition(.opacity)
                                        case .empty:
                                            Color.clear   // placeholder already behind
                                        case .failure:
                                            avatarPlaceholder
                                        @unknown default:
                                            avatarPlaceholder
                                        }
                                    }
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                                .overlay(isUploadingAvatar ? ProgressView().tint(.white) : nil)
                            } else {
                                avatarPlaceholder
                                    .overlay(isUploadingAvatar ? ProgressView().tint(.white) : nil)
                            }
                        }
                        .frame(width: 56, height: 56)
                    }
                    .disabled(isUploadingAvatar)
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        guard let item = newItem else { return }
                        Task { await uploadAvatar(from: item) }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account")
                            .font(.headline)
                        Text(userEmail)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let name = currentUsername, !name.isEmpty {
                            Text("@\(name)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                
                Button(action: { showChangeUsername = true }) {
                    Label("Change username", systemImage: "at.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            } header: {
                Text("Account")
                    .font(.headline)
            } footer: {
                Text("Tap your photo to change it.")
                    .font(.caption)
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
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showContactSupport) {
            NavigationStack {
                ContactSupportView()
            }
        }
        .onAppear {
            if let user = Auth.auth().currentUser {
                userEmail = user.email ?? "No email"
            }
            // Use cached avatar URL immediately so we don't wait on Firestore
            avatarURL = viewModel.avatarURL
            Task {
                currentUsername = await userService.getCurrentUsername()
                // Refresh avatar URL in the background and keep cache in sync
                let freshURL = await userService.getCurrentAvatarURL()
                await MainActor.run {
                    avatarURL = freshURL
                    viewModel.avatarURL = freshURL
                }
            }
        }
        .onChange(of: showChangeUsername) { _, isShowing in
            if !isShowing {
                Task { currentUsername = await userService.getCurrentUsername() }
            }
        }
        .sheet(isPresented: $showChangeUsername) {
            ChangeUsernameView(
                currentUsername: currentUsername,
                userService: userService,
                onDismiss: {
                    showChangeUsername = false
                    Task { currentUsername = await userService.getCurrentUsername() }
                }
            )
        }
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.title3)
            )
    }
    
    private func uploadAvatar(from item: PhotosPickerItem) async {
        isUploadingAvatar = true
        selectedPhotoItem = nil
        defer { isUploadingAvatar = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else { return }
            let urlString = try await userService.uploadAvatar(data: data)
            await MainActor.run {
                avatarURL = urlString
                viewModel.avatarURL = urlString
            }
        } catch {
            print("Avatar upload failed: \(error)")
        }
    }
}


// MARK: - Change Username
struct ChangeUsernameView: View {
    let currentUsername: String?
    @ObservedObject var userService: UserService
    var onDismiss: () -> Void
    
    @State private var username: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isSaving)
                } header: {
                    Text("New username")
                } footer: {
                    Text("\(UserService.usernameMinLength)–\(UserService.usernameMaxLength) characters, letters, numbers, and underscores only.")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Change username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveUsername() }
                    }
                    .disabled(isSaving || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                username = currentUsername ?? ""
            }
            .alert("Username updated", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                    onDismiss()
                }
            } message: {
                Text("Your username is now @\(username.trimmingCharacters(in: .whitespacesAndNewlines)).")
            }
        }
    }
    
    private func saveUsername() async {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validationError = userService.validateUsername(trimmed) {
            errorMessage = validationError
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await userService.updateUsername(trimmed)
            showSuccess = true
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(LoginViewModel())
    }
}

