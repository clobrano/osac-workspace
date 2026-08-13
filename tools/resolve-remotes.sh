#!/usr/bin/env bash
# Consumer wrapper: detect which git remotes point to the upstream org and
# the developer's fork. The real implementation now lives in osac-ai-skills
# (single source of truth, shared with osac-ai-skills-hosted skills like
# create-pr and osac-release) — this delegates to the vendored checkout
# rather than duplicating the logic here.
#
# Usage:
#   eval $(tools/resolve-remotes.sh [OPTIONS] [REPO_PATH])
#   tools/resolve-remotes.sh --print [REPO_PATH]
#
# See the vendored osac-ai-skills/tools/resolve-remotes.sh --help for the
# full option list, output contract, and exit codes — unchanged by this
# wrapper.
#
# Vendor resolution (first match):
#   ~/.osac-ai-skills
#   $WORKSPACE_ROOT/.osac-ai-skills
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

for _cand in "${HOME}/.osac-ai-skills" "${WORKSPACE_ROOT}/.osac-ai-skills"; do
  if [[ -x "${_cand}/tools/resolve-remotes.sh" ]]; then
    exec "${_cand}/tools/resolve-remotes.sh" "$@"
  fi
done

echo "error: resolve-remotes.sh not found in a vendored osac-ai-skills checkout (~/.osac-ai-skills or ${WORKSPACE_ROOT}/.osac-ai-skills)." >&2
echo "  Run ./bootstrap.sh, then retry." >&2
exit 1
