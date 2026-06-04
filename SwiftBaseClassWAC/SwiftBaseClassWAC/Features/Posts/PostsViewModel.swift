//
//  PostsViewModel.swift
//  SwiftBaseClassWAC
//
//  Loads posts through the injected APIClient. Uses constructor injection with
//  a live default so the View is zero-config while tests inject a mock client.
//

import Observation

@Observable
@MainActor
final class PostsViewModel {
    private let apiClient: any APIClient

    private(set) var posts: [Post] = []
    private(set) var isLoading = false
    var error: (any Error)?

    init(apiClient: any APIClient = Dependencies.live.apiClient) {
        self.apiClient = apiClient
    }

    var showsEmptyState: Bool {
        !isLoading && posts.isEmpty && error == nil
    }

    func loadPosts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await apiClient.request(Endpoint(path: "posts"), as: [Post].self)
        } catch {
            self.error = error
        }
    }
}
