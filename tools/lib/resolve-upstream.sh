#!/usr/bin/env bash
# Shared helper: resolve the upstream remote name for a component repo.
# Source this file, set WORKSPACE_DIR, then call resolve_upstream <dir>.
# Falls back to "origin" when resolve-remotes.sh is missing or fails.

resolve_upstream() {
  local dir="$1"
  local script="${WORKSPACE_DIR}/tools/resolve-remotes.sh"
  if [[ -x "$script" ]]; then
    local out
    out=$("$script" "$dir" 2>/dev/null) || { echo "origin"; return; }
    echo "$out" | sed -n 's/^UPSTREAM_REMOTE=//p'
    return
  fi
  echo "origin"
}
