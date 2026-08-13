#!/usr/bin/env bash
# Smoke test for tools/lib/resolve-upstream.sh (the statusline hook's shared
# helper) — run from osac-workspace:
#   bash tools/test/resolve-upstream-smoke.sh
#
# resolve-remotes.sh itself is canonically hosted in osac-ai-skills (OSAC-4005)
# and tested there; this file only covers resolve-upstream.sh's own fallback
# behavior, which is workspace-owned (used by .claude/hooks/statusline.sh).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC2034 # consumed by resolve_upstream() after sourcing HELPER below
WORKSPACE_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)
HELPER="${SCRIPT_DIR}/../lib/resolve-upstream.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

[[ -f "$HELPER" ]] || fail "missing $HELPER"

TMPDIR_ROOT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

make_repo() {
  local dir="$TMPDIR_ROOT/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" -c user.name=test -c user.email=test@test commit --allow-empty -m "init" -q
  echo "$dir"
}

# shellcheck source=../lib/resolve-upstream.sh
source "$HELPER"

test_resolves_via_vendor_lookup() {
  local repo result
  repo=$(make_repo "vendorlookup")
  git -C "$repo" remote add origin "https://github.com/osac-project/vendorlookup.git"
  git -C "$repo" remote add fork "git@github.com:dev/vendorlookup.git"
  result=$(resolve_upstream "$repo")
  [[ "$result" == "origin" ]] || fail "expected 'origin', got '$result'"
  pass "resolve_upstream() finds the vendored resolve-remotes.sh and resolves UPSTREAM_REMOTE"
}

test_hook_fallback_on_script_failure() {
  local repo result
  repo=$(make_repo "hookfallback")
  git -C "$repo" remote add myremote "git@github.com:dev/hookfallback.git"
  result=$(resolve_upstream "$repo")
  [[ "$result" == "origin" ]] || fail "hook fallback: expected 'origin', got '$result'"
  pass "resolve_upstream() falls back to 'origin' when resolve-remotes.sh can't determine upstream"
}

test_hook_fallback_when_vendor_missing() {
  local repo result
  repo=$(make_repo "novendor")
  git -C "$repo" remote add origin "https://github.com/osac-project/novendor.git"
  result=$(HOME="$TMPDIR_ROOT/empty-home" WORKSPACE_DIR="$TMPDIR_ROOT/empty-workspace" resolve_upstream "$repo")
  [[ "$result" == "origin" ]] || fail "expected 'origin' when no vendor checkout is found, got '$result'"
  pass "resolve_upstream() falls back to 'origin' when no vendored osac-ai-skills checkout is found"
}

test_resolves_via_vendor_lookup
test_hook_fallback_on_script_failure
test_hook_fallback_when_vendor_missing

echo "All resolve-upstream smoke tests passed."
