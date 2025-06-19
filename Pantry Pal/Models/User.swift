//
//  User.swift
//  Pantry Pal
//

import Foundation
import Firebase
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    let email: String
    let displayName: String
    let photoURL: String?
    let createdAt: Timestamp
    let updatedAt: Timestamp
}
