//
//  UserService.swift
//  SpotFinder
//
//  Created for username display feature.
//

import Foundation
import FirebaseFirestore
import Combine

class UserService: ObservableObject {
    private let authService = AuthService()
    private let db = Firestore.firestore()
    private let collectionName = "users"
    private let spotsCollectionName = "skateSpots"
    
    /// Favorite spot IDs for the current user (loaded via loadFavorites())
    @Published var favoriteSpotIds: [String] = []
    
    /// Username rules: 3–20 characters, letters/numbers/underscore only
    static let usernameMinLength = 3
    static let usernameMaxLength = 20
    static let usernameAllowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    
    /// Create a new user profile (call after sign up)
    func createProfile(uid: String, username: String, email: String?) async throws {
        let profile = UserProfile(uid: uid, username: username, email: email)
        var data = (try? Firestore.Encoder().encode(profile)) ?? [:]
        data["usernameLowercase"] = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        try await db.collection(collectionName).document(uid).setData(data)
    }
    
    /// Fetch user profile by UID
    func getProfile(uid: String, source: FirestoreSource = .default) async throws -> UserProfile? {
        let document = try await db.collection(collectionName).document(uid).getDocument(source: source)
        guard document.exists else { return nil }
        return try document.data(as: UserProfile.self)
    }
    
    /// Get current user's username (convenience method). Uses server fetch to avoid stale cache.
    /// Reads the "username" field directly so we don't depend on full UserProfile decoding.
    func getCurrentUsername() async -> String? {
        guard let uid = authService.currentUserId else { return nil }
        let doc = try? await db.collection(collectionName).document(uid).getDocument(source: .default)
        guard let data = doc?.data(),
              let name = data["username"] as? String,
              !name.isEmpty else { return nil }
        return name
    }
    
    /// Validate username format (length and allowed characters). Returns nil if valid, or an error message.
    func validateUsername(_ username: String) -> String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Username cannot be empty"
        }
        if trimmed.count < Self.usernameMinLength {
            return "Username must be at least \(Self.usernameMinLength) characters"
        }
        if trimmed.count > Self.usernameMaxLength {
            return "Username must be at most \(Self.usernameMaxLength) characters"
        }
        let allowed = Self.usernameAllowedCharacterSet
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Use only letters, numbers, and underscores"
        }
        return nil
    }
    
    /// Returns true if the username is available (no other user has it, or only the current user has it).
    /// Checks both usernameLowercase (case-insensitive) and exact username for backwards compatibility.
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLower = trimmed.lowercased()
        // Case-insensitive check (requires Firestore index on users.usernameLowercase)
        let byLower = try await db.collection(collectionName)
            .whereField("usernameLowercase", isEqualTo: trimmedLower)
            .limit(to: 2)
            .getDocuments()
        if let other = byLower.documents.first(where: { $0.documentID != uid }) { return false }
        if byLower.documents.isEmpty {
            // Fallback: exact match for legacy users without usernameLowercase
            let byExact = try await db.collection(collectionName)
                .whereField("username", isEqualTo: trimmed)
                .limit(to: 2)
                .getDocuments()
            if let other = byExact.documents.first(where: { $0.documentID != uid }) { return false }
        }
        return true
    }
    
    /// Update username for current user. Validates format and uniqueness, then updates Firestore and denormalized data.
    func updateUsername(_ newUsername: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let trimmed = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = validateUsername(trimmed) {
            throw NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: error])
        }
        let trimmedLower = trimmed.lowercased()
        guard try await isUsernameAvailable(trimmed) else {
            throw NSError(domain: "UserService", code: 409, userInfo: [NSLocalizedDescriptionKey: "That username is already taken"])
        }
        // Store display version and lowercase for uniqueness queries
        try await db.collection(collectionName).document(uid).setData([
            "username": trimmed,
            "usernameLowercase": trimmedLower
        ], merge: true)
        // Update denormalized createdByUsername on spots and comments so "by @username" stays correct
        try await updateDenormalizedUsername(uid: uid, newUsername: trimmed)
    }
    
    /// Update createdByUsername on all spots owned by this user so "by @username" stays correct.
    private func updateDenormalizedUsername(uid: String, newUsername: String) async throws {
        let spotsSnapshot = try await db.collection(spotsCollectionName)
            .whereField("createdBy", isEqualTo: uid)
            .getDocuments()
        guard !spotsSnapshot.documents.isEmpty else { return }
        let batch = db.batch()
        for doc in spotsSnapshot.documents {
            batch.updateData(["createdByUsername": newUsername], forDocument: doc.reference)
        }
        try await batch.commit()
    }
    
    /// Check if user has a profile (for existing users migrating to username system)
    func hasProfile(uid: String) async -> Bool {
        let document = try? await db.collection(collectionName).document(uid).getDocument()
        return document?.exists ?? false
    }
    
    // MARK: - Favorites
    
    /// Load favorite spot IDs from Firestore into favoriteSpotIds.
    func loadFavorites() async {
        guard let uid = authService.currentUserId else {
            await MainActor.run { favoriteSpotIds = [] }
            return
        }
        do {
            let doc = try await db.collection(collectionName).document(uid).getDocument()
            let ids = doc.data()?["favoriteSpotIds"] as? [String] ?? []
            await MainActor.run { favoriteSpotIds = ids }
        } catch {
            print("Error loading favorites: \(error)")
            await MainActor.run { favoriteSpotIds = [] }
        }
    }
    
    /// Add a spot to favorites (current user only).
    func addFavorite(spotId: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        try await db.collection(collectionName).document(uid).setData([
            "favoriteSpotIds": FieldValue.arrayUnion([spotId])
        ], merge: true)
        await MainActor.run {
            if !favoriteSpotIds.contains(spotId) {
                favoriteSpotIds.append(spotId)
            }
        }
    }
    
    /// Remove a spot from favorites (current user only).
    func removeFavorite(spotId: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        try await db.collection(collectionName).document(uid).setData([
            "favoriteSpotIds": FieldValue.arrayRemove([spotId])
        ], merge: true)
        await MainActor.run {
            favoriteSpotIds.removeAll { $0 == spotId }
        }
    }
    
    /// Returns true if the given spot ID is in the current user's favorites.
    func isFavorite(spotId: String) -> Bool {
        favoriteSpotIds.contains(spotId)
    }
}
