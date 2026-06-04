//
//  PostDetailView.swift
//  SwiftBaseClassWAC
//
//  Detail screen for a single post, pushed by the Router.
//

import SwiftUI

struct PostDetailView: View {
    let post: Post

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(post.title)
                    .font(.title2.weight(.bold))
                Text(post.body)
                    .font(.body)
                    .foregroundStyle(AppColor.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.large)
        }
        .navigationTitle("Post #\(post.id)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PostDetailView(post: Post(id: 1, title: "Sample title", body: "Sample body text."))
    }
}
