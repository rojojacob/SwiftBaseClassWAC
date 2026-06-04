//
//  Router.swift
//  SwiftBaseClassWAC
//
//  Observable navigation state for a NavigationStack. Inject it into the
//  environment, bind `path` to the stack, and call push/pop from anywhere.
//

import SwiftUI

@Observable
@MainActor
final class Router {
    var path = NavigationPath()

    func push(_ route: some Hashable) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
