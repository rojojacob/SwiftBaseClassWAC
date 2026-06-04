#!/usr/bin/env bash
# Validates the commit subject against Conventional Commits.
# Wired into Lefthook's commit-msg hook.

set -euo pipefail
msg_file="${1:?usage: check-commit-msg.sh <commit-msg-file>}"
subject="$(head -n1 "$msg_file")"

# Let git's own housekeeping commits through.
case "$subject" in
  Merge*|Revert*|"fixup! "*|"squash! "*) exit 0 ;;
esac

pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-zA-Z0-9 ._/-]+\))?!?: .+'
if [[ ! "$subject" =~ $pattern ]]; then
  echo "✘ Commit subject must follow Conventional Commits:"
  echo "    <type>[(scope)]: <description>"
  echo "  types: feat fix docs style refactor perf test build ci chore revert"
  echo "  got: \"$subject\""
  exit 1
fi
