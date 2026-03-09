//
//  UserProfile.swift
//  SpotFinder
//
//  Created for username display feature.
//

import Foundation
import FirebaseFirestore

struct UserProfile: Codable {
    var uid: String
    var username: String
    var email: String?
    var createdAt: Date
    
    init(uid: String, username: String, email: String? = nil, createdAt: Date = Date()) {
        self.uid = uid
        self.username = username
        self.email = email
        self.createdAt = createdAt
    }
}
