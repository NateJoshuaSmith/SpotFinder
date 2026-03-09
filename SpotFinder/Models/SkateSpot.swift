//
//  SkateSpot.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import Foundation
import FirebaseFirestore

struct SkateSpot: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var latitude: Double
    var longitude: Double
    var comment: String
    var createdBy: String
    var createdByUsername: String?  // Display name; nil for spots created before username feature
    var createdAt: Date
    var updatedAt: Date
    
    init(id: String? = nil, name: String, latitude: Double, longitude: Double, comment: String, createdBy: String, createdByUsername: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.comment = comment
        self.createdBy = createdBy
        self.createdByUsername = createdByUsername
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

