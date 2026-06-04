//
//  PostsViewModelTests.swift
//  SwiftBaseClassWACTests
//
//  Exercises the view model against a mock APIClient (no network) — the
//  payoff of constructor injection.
//

import Foundation
import Testing
@testable import SwiftBaseClassWAC

@MainActor
struct PostsViewModelTests {
    private let postsJSON = #"[{"id":1,"title":"A","body":"a"},{"id":2,"title":"B","body":"b"}]"#

    @Test func loadPopulatesPosts() async {
        let viewModel = PostsViewModel(apiClient: MockAPIClient(result: .json(Data(postsJSON.utf8))))
        await viewModel.loadPosts()
        #expect(viewModel.posts.count == 2)
        #expect(viewModel.error == nil)
        #expect(!viewModel.isLoading)
    }

    @Test func loadSetsErrorOnFailure() async {
        let viewModel = PostsViewModel(apiClient: MockAPIClient(result: .failure(APIError.invalidResponse)))
        await viewModel.loadPosts()
        #expect(viewModel.posts.isEmpty)
        #expect(viewModel.error != nil)
    }

    @Test func requestsThePostsEndpoint() async {
        let mock = MockAPIClient(result: .json(Data("[]".utf8)))
        await PostsViewModel(apiClient: mock).loadPosts()
        #expect(mock.requestedPaths == ["posts"])
    }
}
