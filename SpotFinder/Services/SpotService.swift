//
//  SpotService.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage

class SpotService: ObservableObject {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let collectionName = "skateSpots"
    private let authService = AuthService()
    private let userService = UserService()
    
    @Published var spots: [SkateSpot] = []
    
    // Fetch all spots
    func fetchSpots() async {
        do {
            let snapshot = try await db.collection(collectionName)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            spots = snapshot.documents.compactMap { document in
                try? document.data(as: SkateSpot.self)
            }
        } catch {
            print("Error fetching spots: \(error)")
        }
    }
    
    // Add a new spot (imageURL optional; use uploadSpotImage first if user added a photo)
    func addSpot(name: String, latitude: Double, longitude: Double, comment: String, imageURL: String? = nil) async throws {
        guard let userId = authService.currentUserId else {
            throw NSError(domain: "SpotService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let username = await userService.getCurrentUsername()
        let imageURLs = imageURL.map { [$0] }  // seed array with first image if present
        
        let spot = SkateSpot(
            name: name,
            latitude: latitude,
            longitude: longitude,
            comment: comment,
            createdBy: userId,
            createdByUsername: username,
            imageURL: imageURL,
            imageURLs: imageURLs
        )
        
        do {
            _ = try db.collection(collectionName).addDocument(from: spot)
            await fetchSpots() // Refresh the list
        } catch {
            print("Error adding spot: \(error)")
            throw error
        }
    }
    
    // Delete a spot
    func deleteSpot(_ spot: SkateSpot) async throws {
        guard let spotId = spot.id else { return }
        guard let userId = authService.currentUserId else {
            throw NSError(domain: "SpotService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check if user owns the spot
        guard spot.createdBy == userId else {
            throw NSError(domain: "SpotService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only delete spots you created"])
        }
        
        do {
            try await db.collection(collectionName).document(spotId).delete()
            await fetchSpots() // Refresh the list
        } catch {
            print("Error deleting spot: \(error)")
            throw error
        }
    }
    
    // Update spot coordinates (for dragging)
    func updateSpotLocation(_ spot: SkateSpot, latitude: Double, longitude: Double) async throws {
        guard let spotId = spot.id else { return }
        
        do {
            try await db.collection(collectionName).document(spotId).updateData([
                "latitude": latitude,
                "longitude": longitude,
                "updatedAt": Timestamp(date: Date())
            ])
            await fetchSpots() // Refresh the list
        } catch {
            print("Error updating spot location: \(error)")
            throw error
        }
    }
    
    /// Upload spot image to Firebase Storage; returns the download URL string. Path: spotImages/{userId}/{uuid}.jpg
    func uploadSpotImage(data: Data) async throws -> String {
        guard let userId = authService.currentUserId else {
            throw NSError(domain: "SpotService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        let path = "spotImages/\(userId)/\(UUID().uuidString).jpg"
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
    
    /// Update a spot's image URL (owner only). Call after uploading with uploadSpotImage.
    func updateSpotImage(spot: SkateSpot, imageURL: String) async throws {
        guard let spotId = spot.id else { return }
        guard let userId = authService.currentUserId else {
            throw NSError(domain: "SpotService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        guard spot.createdBy == userId else {
            throw NSError(domain: "SpotService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only update photos for spots you created"])
        }
        try await db.collection(collectionName).document(spotId).updateData([
            "imageURL": imageURL,
            "imageURLs": FieldValue.arrayUnion([imageURL]),
            "updatedAt": Timestamp(date: Date())
        ])
        await fetchSpots()
    }
    
    /// Delete a specific spot image (owner only).
    /// This removes the file from Firebase Storage and its URL from the spot's `imageURLs` array.
    func deleteSpotImage(spot: SkateSpot, imageURL: String) async throws {
        guard let spotId = spot.id else { return }
        guard let userId = authService.currentUserId else {
            throw NSError(domain: "SpotService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        guard spot.createdBy == userId else {
            throw NSError(domain: "SpotService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only delete photos for spots you created"])
        }
        
        do {
            // Delete file from Storage using its download URL
            let ref = storage.reference(forURL: imageURL)
            try await ref.delete()
        } catch {
            // If storage deletion fails, log but still attempt to clean up Firestore reference
            print("Error deleting spot image from storage: \(error)")
        }
        
        var updates: [String: Any] = [
            "imageURLs": FieldValue.arrayRemove([imageURL]),
            "updatedAt": Timestamp(date: Date())
        ]
        
        // If this URL is also stored as the legacy single `imageURL`, clear it
        if spot.imageURL == imageURL {
            updates["imageURL"] = FieldValue.delete()
        }
        
        try await db.collection(collectionName).document(spotId).updateData(updates)
        await fetchSpots()
    }
    
    // Listen for real-time updates (optional - for real-time sync)
    func listenToSpots() {
        db.collection(collectionName)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.spots = documents.compactMap { document in
                    try? document.data(as: SkateSpot.self)
                }
            }
    }
}

