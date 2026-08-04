#!/usr/bin/env bash
# Thin wrapper -- kind-dev was migrated into the osac mono-repo (e05e19e9).
# This delegates to that copy so there's a single source of truth for the
# actual setup logic and its sibling values/manifest files; this wrapper
# exists only for the "run it from osac-workspace root" convenience. All
# flags and env vars (--skip-osac, --cluster-only, CLUSTER_NAME,
# OSAC_NAMESPACE, KEYCLOAK_NAMESPACE, KIND_EXPERIMENTAL_PROVIDER,
# FULFILLMENT_IMAGE, etc.) pass through as-is -- see osac/kind-dev/setup.sh
# for the full usage/environment-variable reference.
set -euo pipefail

SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
REAL_SCRIPT="${SCRIPT_DIR}/../osac/kind-dev/setup.sh"

if [[ ! -f "${REAL_SCRIPT}" ]]; then
  echo "osac/kind-dev/setup.sh not found -- run ./bootstrap.sh to clone osac first." >&2
  exit 1
fi
if [[ ! -x "${REAL_SCRIPT}" ]]; then
  echo "osac/kind-dev/setup.sh is not executable -- run: chmod +x osac/kind-dev/setup.sh" >&2
  exit 1
fi

# realpath'd so the real script's own $0-based usage/error output (e.g.
# --help, teardown.sh's "$0 [--keep-data]") shows a clean canonical path
# instead of one with a literal ".." segment in it.
exec "$(realpath "${REAL_SCRIPT}")" "$@"
