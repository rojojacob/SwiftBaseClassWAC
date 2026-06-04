#!/usr/bin/env bash
# Shared helpers sourced by the other scripts in this directory.
# Source it with:  source "$(dirname "$0")/_helpers.sh"

set -euo pipefail

# Repo + project layout (single source of truth for the scripts).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj"
SCHEME="SwiftBaseClassWAC"

# Colored logging.
if [ -t 1 ]; then
  _C_RESET="\033[0m"; _C_RED="\033[31m"; _C_GREEN="\033[32m"; _C_YELLOW="\033[33m"; _C_BLUE="\033[34m"
else
  _C_RESET=""; _C_RED=""; _C_GREEN=""; _C_YELLOW=""; _C_BLUE=""
fi

log_info() { printf "${_C_BLUE}ℹ %s${_C_RESET}\n" "$*"; }
log_success() { printf "${_C_GREEN}✔ %s${_C_RESET}\n" "$*"; }
log_warning() { printf "${_C_YELLOW}⚠ %s${_C_RESET}\n" "$*"; }
log_error() { printf "${_C_RED}✘ %s${_C_RESET}\n" "$*" >&2; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# A simulator that exists on most machines/runners; override with SIMULATOR env.
DESTINATION="platform=iOS Simulator,name=${SIMULATOR:-iPhone 16}"

# Pretty-print xcodebuild output if xcbeautify is available.
beautify() {
  if command_exists xcbeautify; then xcbeautify; else cat; fi
}
