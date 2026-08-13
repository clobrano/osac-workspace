#!/usr/bin/env bash
# Consumer wrapper: temp-file and Jira-credential helpers for jira-cli safe
# create (mktemp + EXIT trap cleanup, plus jira_login()/jira_token() for
# skills that need direct REST calls). The real implementation now lives in
# osac-ai-skills (single source of truth, shared with osac-ai-skills-hosted
# skills like jira-task-management and report-bug) — this delegates to the
# vendored checkout rather than duplicating the functions here.
#
# Source (do not execute — defines shell functions):
#   source "$(git rev-parse --show-toplevel)/tools/jira-safe-create.sh"
#
# Vendor resolution (first match):
#   ~/.osac-ai-skills
#   $WORKSPACE_ROOT/.osac-ai-skills

_jsc_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_jsc_workspace_root="$(cd "${_jsc_script_dir}/.." && pwd)"
_jsc_vendor=""
for _jsc_cand in "${HOME}/.osac-ai-skills" "${_jsc_workspace_root}/.osac-ai-skills"; do
  if [[ -f "${_jsc_cand}/tools/jira-safe-create.sh" ]]; then
    _jsc_vendor="${_jsc_cand}/tools/jira-safe-create.sh"
    break
  fi
done

if [[ -z "$_jsc_vendor" ]]; then
  echo "error: jira-safe-create.sh not found in a vendored osac-ai-skills checkout (~/.osac-ai-skills or ${_jsc_workspace_root}/.osac-ai-skills)." >&2
  echo "  Run ./bootstrap.sh, then retry." >&2
  unset _jsc_script_dir _jsc_workspace_root _jsc_vendor _jsc_cand
  return 1 2>/dev/null || exit 1
fi

# shellcheck source=/dev/null
source "$_jsc_vendor"
unset _jsc_script_dir _jsc_workspace_root _jsc_vendor _jsc_cand
