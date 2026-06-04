//
//  Post.swift
//  SwiftBaseClassWAC
//
//  Domain model for the Posts sample feature (shape matches the public
//  jsonplaceholder.typicode.com/posts API used by the dev environment).
//

/// `nonisolated` so its Decodable/Sendable conformances aren't main-actor
/// isolated (the project defaults types to @MainActor); required to decode it
/// from the nonisolated networking layer.
nonisolated struct Post: Identifiable, Decodable, Hashable {
    let id: Int
    let title: String
    let body: String
}
