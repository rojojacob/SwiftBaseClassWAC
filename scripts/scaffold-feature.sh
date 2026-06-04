#!/usr/bin/env bash
# Scaffold a new MVVM feature (Model + @Observable ViewModel + View) and a
# matching unit test. Synchronized Xcode groups pick the files up automatically.
#
# Usage:  ./scripts/scaffold-feature.sh <FeatureName>
# Example: ./scripts/scaffold-feature.sh Profile

source "$(dirname "$0")/_helpers.sh"
cd "$REPO_ROOT"

NAME="${1:-}"
if [ -z "$NAME" ]; then
  log_error "Usage: ./scripts/scaffold-feature.sh <FeatureName>"
  exit 1
fi
if ! [[ "$NAME" =~ ^[A-Z][A-Za-z0-9]*$ ]]; then
  log_error "Feature name must be PascalCase (e.g. Profile, UserSettings). Got: '$NAME'"
  exit 1
fi

FEATURE_DIR="SwiftBaseClassWAC/SwiftBaseClassWAC/Features/$NAME"
TEST_DIR="SwiftBaseClassWAC/SwiftBaseClassWACTests/Features"
if [ -d "$FEATURE_DIR" ]; then
  log_error "Feature '$NAME' already exists at $FEATURE_DIR"
  exit 1
fi
mkdir -p "$FEATURE_DIR" "$TEST_DIR"

cat > "$FEATURE_DIR/${NAME}Model.swift" <<EOF
//
//  ${NAME}Model.swift
//  SwiftBaseClassWAC
//

struct ${NAME}Model: Equatable, Sendable {
    // TODO: domain state for $NAME
}
EOF

cat > "$FEATURE_DIR/${NAME}ViewModel.swift" <<EOF
//
//  ${NAME}ViewModel.swift
//  SwiftBaseClassWAC
//

import Observation

@Observable
@MainActor
final class ${NAME}ViewModel {
    private let apiClient: any APIClient

    init(apiClient: any APIClient = Dependencies.live.apiClient) {
        self.apiClient = apiClient
    }

    func onAppear() async {
        // TODO: load data via apiClient
    }
}
EOF

cat > "$FEATURE_DIR/${NAME}View.swift" <<EOF
//
//  ${NAME}View.swift
//  SwiftBaseClassWAC
//

import SwiftUI

struct ${NAME}View: View {
    @State private var viewModel = ${NAME}ViewModel()

    var body: some View {
        ContentUnavailableView("$NAME", systemImage: "square.dashed")
            .navigationTitle("$NAME")
            .task { await viewModel.onAppear() }
    }
}

#Preview {
    NavigationStack {
        ${NAME}View()
    }
}
EOF

cat > "$TEST_DIR/${NAME}ViewModelTests.swift" <<EOF
//
//  ${NAME}ViewModelTests.swift
//  SwiftBaseClassWACTests
//

import Testing
@testable import SwiftBaseClassWAC

@MainActor
struct ${NAME}ViewModelTests {
    @Test func placeholder() {
        _ = ${NAME}ViewModel(apiClient: MockAPIClient())
        #expect(Bool(true)) // TODO: real assertions
    }
}
EOF

log_success "Created feature '$NAME':"
echo "  $FEATURE_DIR/${NAME}{Model,ViewModel,View}.swift"
echo "  $TEST_DIR/${NAME}ViewModelTests.swift"
log_info "Add a route in App/HomeView.swift + App/RootView.swift to surface it."
