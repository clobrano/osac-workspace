#!/usr/bin/env bash
# Shared helper: resolve the upstream remote name for a component repo.
# Source this file, set WORKSPACE_DIR, then call resolve_upstream <dir>.
# Falls back to "origin" when the vendored osac-ai-skills checkout (and its
# resolve-remotes.sh) can't be found, or the script itself fails — this is a
# non-critical status-line display, not a push-critical path, so a soft
# fallback (rather than a hard error) is the right tradeoff here.

resolve_upstream() {
  local dir="$1"
  local script cand
  for cand in "${HOME}/.osac-ai-skills" "${WORKSPACE_DIR}/.osac-ai-skills"; do
    if [[ -x "${cand}/tools/resolve-remotes.sh" ]]; then
      script="${cand}/tools/resolve-remotes.sh"
      break
    fi
  done
  if [[ -n "${script:-}" ]]; then
    local out
    out=$("$script" "$dir" 2>/dev/null) || { echo "origin"; return; }
    echo "$out" | sed -n 's/^UPSTREAM_REMOTE=//p'
    return
  fi
  echo "origin"
}
