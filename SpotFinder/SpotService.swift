//
//  SpotService.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

class SpotService: ObservableObject {
    private let db = Firestore.firestore()
    private let collectionName = "skateSpots"
    
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
    
    // Add a new spot
    func addSpot(name: String, latitude: Double, longitude: Double, comment: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "SpotService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let spot = SkateSpot(
            name: name,
            latitude: latitude,
            longitude: longitude,
            comment: comment,
            createdBy: userId
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
        guard let userId = Auth.auth().currentUser?.uid else {
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

