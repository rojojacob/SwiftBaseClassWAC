#!/usr/bin/env bash
# The single "is this code good?" gate — format check, lint, build, test.
# Run it locally before pushing; CI runs the same steps.
#
# Usage:  ./scripts/preflight.sh

source "$(dirname "$0")/_helpers.sh"
cd "$REPO_ROOT"

failures=0
step() {
  local name="$1"; shift
  log_info "$name…"
  if "$@"; then log_success "$name"; else log_error "$name failed"; failures=$((failures + 1)); fi
}

step "SwiftFormat (lint)" swiftformat --lint .
step "SwiftLint (strict)" swiftlint lint --strict
step "Build & test" bash -c "set -o pipefail; xcodebuild test \
  -project '$PROJECT' -scheme '$SCHEME' -destination '$DESTINATION' | beautify"

echo
if [ "$failures" -eq 0 ]; then
  log_success "Preflight passed 🎉"
else
  log_error "Preflight failed ($failures step(s))"
  exit 1
fi
