//
//  RootView.swift
//  SwiftBaseClassWAC
//
//  Top-level navigation host. Owns the Router, binds it to the NavigationStack,
//  and registers navigation destinations. Add new feature routes here.
//

import SwiftUI

struct RootView: View {
    @State private var router = Router()

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .counter: CounterView()
                    case .posts: PostsListView()
                    }
                }
                .navigationDestination(for: Post.self) { post in
                    PostDetailView(post: post)
                }
        }
        .environment(router)
    }
}

#Preview {
    RootView()
}
