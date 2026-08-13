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

# Locate the real vendored resolve-remotes.sh once, to copy into isolated
# per-test fixtures below. This keeps the two tests below hermetic (they
# don't depend on which vendor candidate this machine happens to have) while
# still exercising the real script rather than a hand-rolled stub.
REAL_RESOLVE_REMOTES=""
for _cand in "${HOME}/.osac-ai-skills" "${WORKSPACE_DIR}/.osac-ai-skills"; do
  [[ -x "${_cand}/tools/resolve-remotes.sh" ]] && { REAL_RESOLVE_REMOTES="${_cand}/tools/resolve-remotes.sh"; break; }
done
[[ -n "$REAL_RESOLVE_REMOTES" ]] || fail "no vendored resolve-remotes.sh found on this machine to fixture from — run ./bootstrap.sh"

make_vendor_fixture() {
  local vendor_dir="$1"
  mkdir -p "${vendor_dir}/tools"
  cp "$REAL_RESOLVE_REMOTES" "${vendor_dir}/tools/resolve-remotes.sh"
  chmod +x "${vendor_dir}/tools/resolve-remotes.sh"
}

# Reversed naming (origin=fork, upstream=upstream) on purpose: the correct
# answer here is "upstream", distinguishable from the fallback default of
# "origin" — so if vendor lookup silently failed and fell back instead of
# actually resolving, these tests would fail instead of passing by accident.

test_resolves_via_home_vendor_lookup() {
  local repo fake_home result
  repo=$(make_repo "homevendor")
  git -C "$repo" remote add origin "git@github.com:dev/homevendor.git"
  git -C "$repo" remote add upstream "https://github.com/osac-project/homevendor.git"
  fake_home="${TMPDIR_ROOT}/fake-home-vendor"
  make_vendor_fixture "${fake_home}/.osac-ai-skills"
  result=$(HOME="$fake_home" WORKSPACE_DIR="${TMPDIR_ROOT}/no-such-workspace" resolve_upstream "$repo")
  [[ "$result" == "upstream" ]] || fail "HOME candidate: expected 'upstream', got '$result' (vendor lookup may have silently fallen back)"
  pass "resolve_upstream() resolves via the \$HOME/.osac-ai-skills candidate"
}

test_resolves_via_workspace_vendor_lookup() {
  local repo fake_workspace result
  repo=$(make_repo "workspacevendor")
  git -C "$repo" remote add origin "git@github.com:dev/workspacevendor.git"
  git -C "$repo" remote add upstream "https://github.com/osac-project/workspacevendor.git"
  fake_workspace="${TMPDIR_ROOT}/fake-workspace-vendor"
  make_vendor_fixture "${fake_workspace}/.osac-ai-skills"
  result=$(HOME="${TMPDIR_ROOT}/no-such-home" WORKSPACE_DIR="$fake_workspace" resolve_upstream "$repo")
  [[ "$result" == "upstream" ]] || fail "WORKSPACE_DIR candidate: expected 'upstream', got '$result' (vendor lookup may have silently fallen back)"
  pass "resolve_upstream() resolves via the \$WORKSPACE_DIR/.osac-ai-skills candidate (used when \$HOME/.osac-ai-skills is absent)"
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

test_resolves_via_home_vendor_lookup
test_resolves_via_workspace_vendor_lookup
test_hook_fallback_on_script_failure
test_hook_fallback_when_vendor_missing

echo "All resolve-upstream smoke tests passed."
