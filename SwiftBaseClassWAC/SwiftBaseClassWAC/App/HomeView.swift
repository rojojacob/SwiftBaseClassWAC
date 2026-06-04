//
//  HomeView.swift
//  SwiftBaseClassWAC
//
//  Landing screen listing the feature demos. Navigation is driven through the
//  shared Router so any screen can push routes.
//

import SwiftUI

enum HomeRoute: Hashable {
    case counter
    case posts
}

struct HomeView: View {
    @Environment(Router.self) private var router

    var body: some View {
        List {
            Section("Features") {
                row("Counter", systemImage: "plusminus.circle", route: .counter)
                    .accessibilityIdentifier("home.counter")
                row("Posts", systemImage: "list.bullet.rectangle", route: .posts)
                    .accessibilityIdentifier("home.posts")
            }
        }
        .navigationTitle("SwiftBaseClassWAC")
    }

    private func row(_ title: String, systemImage: String, route: HomeRoute) -> some View {
        Button {
            router.push(route)
        } label: {
            Label(title, systemImage: systemImage)
        }
        .foregroundStyle(AppColor.primaryText)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(Router())
}
