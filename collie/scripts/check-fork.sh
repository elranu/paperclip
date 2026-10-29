#!/usr/bin/env bash
# Fail when a changed upstream file is not in the FORK.md ledger.
# Usage: check-fork.sh [--working-tree]
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/fork-ledger.sh
source "$here/lib/fork-ledger.sh"

working_tree=0
for arg in "$@"; do
  case "$arg" in
    --working-tree) working_tree=1 ;;
    -h|--help) sed -n '2,3p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "check-fork: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

root="$(collie_root)"
cd "$root"

tag="$(tr -d '[:space:]' < collie/UPSTREAM)"
if ! git rev-parse -q --verify "refs/tags/$tag^{commit}" >/dev/null; then
  echo "check-fork: tag '$tag' (from collie/UPSTREAM) is not in this clone." >&2
  echo "Run: git fetch upstream --tags   (or: git fetch --tags)" >&2
  exit 2
fi

changed="$(git diff --name-only --no-renames "$tag" HEAD)"
if [ "$working_tree" -eq 1 ]; then
  changed+=$'\n'"$(git diff --name-only --no-renames "$tag")"
  changed+=$'\n'"$(git ls-files --others --exclude-standard)"
fi
changed="$(printf '%s\n' "$changed" | sed '/^$/d' | sort -u)"

ledger="$(collie_ledger_rows FORK.md | cut -f1)"

missing=()
while IFS= read -r file; do
  [ -n "$file" ] || continue
  collie_is_green "$file" && continue
  if ! grep -Fxq -- "$file" <<<"$ledger"; then
    missing+=("$file")
  fi
done <<<"$changed"

if [ "${#missing[@]}" -gt 0 ]; then
  echo "check-fork: FAILED. These upstream files changed since $tag" >&2
  echo "and are not in the FORK.md ledger:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  echo "Add a row for each file to FORK.md, or revert the change." >&2
  exit 1
fi

echo "check-fork: OK"
