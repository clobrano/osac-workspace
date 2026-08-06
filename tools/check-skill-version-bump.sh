#!/usr/bin/env bash
# Fails a PR if a skills/*/SKILL.md file with a version field (top-level
# `version:` or nested `metadata.version:`) changed content without also
# changing that version string. No semver comparison - just "did it change?"
# Usage: tools/check-skill-version-bump.sh <base-ref>
set -euo pipefail

# Paths to skip entirely, relative to repo root, e.g. "skills/example/SKILL.md".
IGNORE_PATHS=(
)

BASE_REF="${1:?Usage: $0 <base-ref>}"

is_ignored() {
  local path=$1
  local ignored
  for ignored in "${IGNORE_PATHS[@]:-}"; do
    [[ "$path" == "$ignored" ]] && return 0
  done
  return 1
}

# Only matches a top-level `version:` or a `version:` nested directly under a
# top-level `metadata:` block -- not version keys under other mappings (e.g.
# a hypothetical `release.version`), which aren't part of the skill's own
# declared version.
extract_version() {
  local ref=$1 path=$2
  { git show "${ref}:${path}" 2>/dev/null || true; } \
    | awk '
      /^---[[:space:]]*$/ { c++; next }
      c != 1 { next }
      /^version:[[:space:]]*/ { sub(/^version:[[:space:]]*/, ""); print; exit }
      /^metadata:[[:space:]]*$/ { in_meta=1; next }
      in_meta && /^[^[:space:]]/ { in_meta=0 }
      in_meta && /^[[:space:]]+version:[[:space:]]*/ { sub(/^[[:space:]]+version:[[:space:]]*/, ""); print; exit }
    ' \
    | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/' \
    | sed -E 's/[[:space:]]+$//'
}

if ! CHANGED_PATHS=$(git diff --diff-filter=d --name-only "${BASE_REF}...HEAD" -- 'skills'); then
  echo "ERROR: Cannot diff ${BASE_REF}...HEAD -- is the base ref valid and fetched?" >&2
  exit 2
fi

mapfile -t CHANGED_FILES < <(
  printf '%s\n' "$CHANGED_PATHS" | grep -iE '^skills/[^/]+/SKILL\.md$' || true
)

if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
  echo "No changed skills/*/SKILL.md files."
  exit 0
fi

FAILED=0

for path in "${CHANGED_FILES[@]}"; do
  if is_ignored "$path"; then
    echo "⏭️  SKIP: ${path} (ignored)"
    continue
  fi

  head_version=$(extract_version "HEAD" "$path")
  base_version=$(extract_version "${BASE_REF}" "$path")

  if [[ -z "$head_version" && -z "$base_version" ]]; then
    echo "⏭️  SKIP: ${path} (no version in frontmatter)"
    continue
  fi

  if [[ -z "$head_version" ]]; then
    echo "❌ FAIL: ${path} version field was removed (was ${base_version})"
    FAILED=1
    continue
  fi

  if [[ -z "$base_version" ]]; then
    echo "✅ PASS: ${path} (version field added: ${head_version})"
    continue
  fi

  if [[ "$head_version" == "$base_version" ]]; then
    echo "❌ FAIL: ${path} changed but version was not bumped (still ${head_version})"
    FAILED=1
  else
    echo "✅ PASS: ${path} (version: ${base_version} -> ${head_version})"
  fi
done

if [[ "$FAILED" -ne 0 ]]; then
  echo
  echo "ERROR: Some SKILL.md files were modified without a version bump."
  echo "Please update the version in the frontmatter of the affected files."
  exit 1
fi

exit 0
