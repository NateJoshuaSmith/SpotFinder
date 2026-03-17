//
//  FriendsListView.swift
//  SpotFinder
//
//  List of the current user's friends; search and add by username.
//

import SwiftUI
import FirebaseAuth

struct FriendsListView: View {
    @StateObject private var userService = UserService()
    @State private var friends: [UserProfile] = []
    @State private var pendingSentProfiles: [UserProfile] = []
    @State private var pendingReceived: [(FriendRequest, UserProfile)] = []
    @State private var isLoading = true
    @State private var showAddFriend = false
    
    private var isLoggedIn: Bool {
        Auth.auth().currentUser != nil
    }
    
    private var hasAnyContent: Bool {
        !friends.isEmpty || !pendingSentProfiles.isEmpty || !pendingReceived.isEmpty
    }
    
    var body: some View {
        ZStack {
            // Friends list background image with dark overlay, similar to Home
            Image("FriendslistBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            
            Group {
                if !isLoggedIn {
                    ContentUnavailableView(
                        "Sign in to see friends",
                        systemImage: "person.2.slash",
                        description: Text("Log in to add and view your friends list.")
                    )
                } else if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading friends...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasAnyContent {
                    ContentUnavailableView(
                        "No friends yet",
                        systemImage: "person.2",
                        description: Text("Tap \"Add friend\" to search by username and add people.")
                    )
                } else {
                    List {
                        if !pendingReceived.isEmpty {
                            Section("Requests") {
                                ForEach(pendingReceived, id: \.0.fromUid) { request, profile in
                                    HStack {
                                        Spacer(minLength: 0)
                                        
                                        HStack(spacing: 12) {
                                            FriendRow(profile: profile, onRemove: nil)
                                            Spacer()
                                            Button("Accept") {
                                                Task { await acceptRequest(request.fromUid) }
                                            }
                                            .buttonStyle(.borderedProminent)
                                            Button("Decline", role: .destructive) {
                                                Task { await declineRequest(request.fromUid) }
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.95))
                                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                                        )
                                        .frame(maxWidth: 360)
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                }
                            }
                        }
                        if !friends.isEmpty {
                            Section("Friends") {
                                ForEach(friends, id: \.uid) { profile in
                                    HStack {
                                        Spacer(minLength: 0)
                                        
                                        HStack(spacing: 0) {
                                            NavigationLink(destination: ConversationView(friendProfile: profile)) {
                                                FriendRow(profile: profile, onRemove: nil)
                                            }
                                            Button(role: .destructive) {
                                                Task { await removeFriend(profile.uid) }
                                            } label: {
                                                Text("Remove")
                                                    .font(.subheadline)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.95))
                                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                                        )
                                        .frame(maxWidth: 360)
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                }
                            }
                        }
                        if !pendingSentProfiles.isEmpty {
                            Section("Pending") {
                                ForEach(pendingSentProfiles, id: \.uid) { profile in
                                    HStack {
                                        Spacer(minLength: 0)
                                        
                                        HStack(spacing: 12) {
                                            FriendRow(profile: profile, onRemove: nil)
                                            Spacer()
                                            Text("Pending")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Button("Cancel", role: .destructive) {
                                                Task { await cancelRequest(profile.uid) }
                                            }
                                            .buttonStyle(.borderless)
                                            .font(.subheadline)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.95))
                                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                                        )
                                        .frame(maxWidth: 360)
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            Task { await cancelRequest(profile.uid) }
                                        } label: {
                                            Label("Cancel request", systemImage: "xmark.circle")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden) // let the FriendslistBackground show through
                }
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoggedIn {
                    Button(action: { showAddFriend = true }) {
                        Label("Add friend", systemImage: "person.badge.plus")
                    }
                }
            }
        }
        .task {
            await loadFriends()
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendView(userService: userService) {
                showAddFriend = false
                Task { await refreshAll() }
            }
        }
    }
    
    /// Full load from Firestore: friends, pending sent, pending received.
    private func loadFriends() async {
        guard isLoggedIn else {
            isLoading = false
            return
        }
        isLoading = true
        await userService.loadFriends()
        await userService.loadPendingSent()
        await userService.processAcceptedRequests()
        await refreshFriendsFromCurrentIds()
        await refreshPendingSentProfiles()
        await loadPendingReceived()
        await MainActor.run { isLoading = false }
    }
    
    /// Refresh friends and pending lists from current in-memory state (e.g. after adding a friend).
    private func refreshAll() async {
        guard isLoggedIn else { return }
        await userService.loadPendingSent()
        await refreshFriendsFromCurrentIds()
        await refreshPendingSentProfiles()
        await loadPendingReceived()
    }
    
    private func refreshFriendsFromCurrentIds() async {
        guard isLoggedIn else { return }
        let ids = userService.friendIds
        var loaded: [UserProfile] = []
        for id in ids {
            if let profile = try? await userService.getProfile(uid: id) {
                loaded.append(profile)
            }
        }
        await MainActor.run { friends = loaded }
    }
    
    private func refreshPendingSentProfiles() async {
        let ids = userService.pendingSentIds
        var loaded: [UserProfile] = []
        for id in ids {
            if let profile = try? await userService.getProfile(uid: id) {
                loaded.append(profile)
            }
        }
        await MainActor.run { pendingSentProfiles = loaded }
    }
    
    private func loadPendingReceived() async {
        guard let requests = try? await userService.loadPendingReceived() else {
            await MainActor.run { pendingReceived = [] }
            return
        }
        var result: [(FriendRequest, UserProfile)] = []
        for request in requests {
            if let profile = try? await userService.getProfile(uid: request.fromUid) {
                result.append((request, profile))
            }
        }
        await MainActor.run { pendingReceived = result }
    }
    
    private func removeFriend(_ uid: String) async {
        do {
            try await userService.removeFriend(friendUid: uid)
            await MainActor.run { friends.removeAll { $0.uid == uid } }
        } catch {
            print("Error removing friend: \(error)")
        }
    }
    
    private func cancelRequest(_ toUid: String) async {
        do {
            try await userService.cancelFriendRequest(toUid: toUid)
            await MainActor.run { pendingSentProfiles.removeAll { $0.uid == toUid } }
        } catch {
            print("Error canceling request: \(error)")
        }
    }
    
    private func acceptRequest(_ fromUid: String) async {
        do {
            try await userService.acceptFriendRequest(fromUid: fromUid)
            await MainActor.run { pendingReceived.removeAll { $0.0.fromUid == fromUid } }
            await refreshFriendsFromCurrentIds()
        } catch {
            print("Error accepting request: \(error)")
        }
    }
    
    private func declineRequest(_ fromUid: String) async {
        do {
            try await userService.declineFriendRequest(fromUid: fromUid)
            await MainActor.run { pendingReceived.removeAll { $0.0.fromUid == fromUid } }
        } catch {
            print("Error declining request: \(error)")
        }
    }
}

private struct FriendRow: View {
    let profile: UserProfile
    var onRemove: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            avatarView
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.username)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("@\(profile.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if onRemove != nil {
                Button(role: .destructive, action: onRemove!) {
                    Text("Remove")
                        .font(.subheadline)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var avatarView: some View {
        Group {
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
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
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
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.body)
            )
    }
}

#Preview {
    NavigationStack {
        FriendsListView()
    }
}
