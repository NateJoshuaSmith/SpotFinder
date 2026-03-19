//
//  UserProfileView.swift
//  SpotFinder
//
//  Simple profile page for a SpotFinder user.
//

import SwiftUI
import FirebaseAuth

struct UserProfileView: View {
    let profile: UserProfile
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userService = UserService()
    @State private var isSendingRequest = false
    @State private var requestError: String?
    
    private var isCurrentUser: Bool {
        Auth.auth().currentUser?.uid == profile.uid
    }
    
    private var isFriend: Bool {
        userService.isFriend(uid: profile.uid)
    }
    
    private var hasPendingSent: Bool {
        userService.hasPendingSentRequest(toUid: profile.uid)
    }
    
    private var formattedJoinDate: String? {
        guard let createdAt = profile.createdAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Avatar
                avatarView
                    .padding(.top, 24)
                
                // Username + basic info
                VStack(spacing: 8) {
                    Text(profile.username)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if let email = profile.email, !email.isEmpty, isCurrentUser {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let join = formattedJoinDate {
                        Text("Member since \(join)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    if isCurrentUser {
                        Text("This is your profile")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                // Actions
                if !isCurrentUser {
                    VStack(spacing: 12) {
                        NavigationLink(destination: ConversationView(friendProfile: profile)) {
                            Label("Message", systemImage: "bubble.left.and.bubble.right.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            Task { await sendFriendRequest() }
                        } label: {
                            if isFriend {
                                Label("Already friends", systemImage: "checkmark.circle.fill")
                            } else if hasPendingSent {
                                Label("Request sent", systemImage: "clock.fill")
                            } else if isSendingRequest {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Label("Add friend", systemImage: "person.badge.plus")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            (isFriend || hasPendingSent || isSendingRequest) ? Color.gray : Color.green
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(isFriend || hasPendingSent || isSendingRequest)
                        
                        if let error = requestError {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                        
                        Text("You can start a conversation or manage friendship from the Friends screen.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 0)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
                .overlay(Color.black.opacity(0.45).ignoresSafeArea())
        )
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await userService.loadFriends()
            await userService.loadPendingSent()
        }
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if let urlString = profile.avatarURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    avatarPlaceholder
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .shadow(radius: 6)
        } else {
            avatarPlaceholder
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .shadow(radius: 6)
        }
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
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.title)
            )
    }
}

extension UserProfileView {
    private func sendFriendRequest() async {
        guard !isFriend, !hasPendingSent, !isSendingRequest else { return }
        await MainActor.run {
            isSendingRequest = true
            requestError = nil
        }
        do {
            try await userService.createFriendRequest(toUid: profile.uid)
            await userService.loadPendingSent()
        } catch {
            await MainActor.run {
                requestError = (error as NSError).localizedDescription
            }
        }
        await MainActor.run {
            isSendingRequest = false
        }
    }
}

