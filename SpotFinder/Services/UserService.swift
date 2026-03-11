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
    
    /// Create a new user profile (call after sign up)
    func createProfile(uid: String, username: String, email: String?) async throws {
        let profile = UserProfile(uid: uid, username: username, email: email)
        try db.collection(collectionName).document(uid).setData(from: profile)
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
    
    /// Update username for current user
    func updateUsername(_ newUsername: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        // Update only the username field with merge so the document is created if missing
        try await db.collection(collectionName).document(uid).setData(["username": newUsername], merge: true)
    }
    
    /// Check if user has a profile (for existing users migrating to username system)
    func hasProfile(uid: String) async -> Bool {
        let document = try? await db.collection(collectionName).document(uid).getDocument()
        return document?.exists ?? false
    }
}
