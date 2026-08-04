#!/usr/bin/env bash
# Thin wrapper -- kind-dev was migrated into the osac mono-repo (e05e19e9).
# Delegates to that copy (which sources its own sibling setup.sh for shared
# helpers) so there's a single source of truth. See osac/kind-dev/setup.sh
# for the wrapper design rationale.
set -euo pipefail

SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
REAL_SCRIPT="${SCRIPT_DIR}/../osac/kind-dev/teardown.sh"

if [[ ! -f "${REAL_SCRIPT}" ]]; then
  echo "osac/kind-dev/teardown.sh not found -- run ./bootstrap.sh to clone osac first." >&2
  exit 1
fi
if [[ ! -x "${REAL_SCRIPT}" ]]; then
  echo "osac/kind-dev/teardown.sh is not executable -- run: chmod +x osac/kind-dev/teardown.sh" >&2
  exit 1
fi

# realpath'd so the real script's own $0-based usage output ("$0 [--keep-data]")
# shows a clean canonical path instead of one with a literal ".." segment in it.
exec "$(realpath "${REAL_SCRIPT}")" "$@"
