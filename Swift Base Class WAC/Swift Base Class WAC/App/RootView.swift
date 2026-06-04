//
//  RootView.swift
//  Swift Base Class WAC
//
//  Top-level navigation host. Wire feature entry points here.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            CounterView()
        }
    }
}

#Preview {
    RootView()
}
