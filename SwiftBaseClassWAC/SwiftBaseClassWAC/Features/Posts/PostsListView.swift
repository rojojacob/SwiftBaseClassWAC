//
//  PostsListView.swift
//  SwiftBaseClassWAC
//
//  Sample networked feature: lists posts, pull-to-refresh, pushes detail via
//  the Router, and surfaces errors with the shared .errorAlert modifier.
//

import SwiftUI

struct PostsListView: View {
    @Environment(Router.self) private var router
    @State private var viewModel = PostsViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        List(viewModel.posts) { post in
            Button {
                router.push(post)
            } label: {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(post.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(post.body)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.secondaryText)
                        .lineLimit(2)
                }
            }
            .foregroundStyle(AppColor.primaryText)
        }
        .overlay {
            if viewModel.isLoading, viewModel.posts.isEmpty {
                ProgressView()
            } else if viewModel.showsEmptyState {
                ContentUnavailableView("No Posts", systemImage: "tray")
            }
        }
        .refreshable { await viewModel.loadPosts() }
        .navigationTitle("Posts")
        .errorAlert($viewModel.error)
        .task { await viewModel.loadPosts() }
        .accessibilityIdentifier("posts.list")
    }
}

#Preview {
    NavigationStack {
        PostsListView()
    }
    .environment(Router())
}
