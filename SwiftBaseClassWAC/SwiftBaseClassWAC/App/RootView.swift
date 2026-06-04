//
//  RootView.swift
//  SwiftBaseClassWAC
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
