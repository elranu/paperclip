#!/usr/bin/env bash
# Trial-merge the newest upstream release tag in a temporary worktree.
# Usage: sync-upstream.sh --dry-run
# Never touches the current working tree or branch.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/fork-ledger.sh
source "$here/lib/fork-ledger.sh"

dry_run=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    -h|--help) sed -n '2,4p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "sync-upstream: unknown argument: $arg" >&2; exit 2 ;;
  esac
done
if [ "$dry_run" -ne 1 ]; then
  echo "sync-upstream: not implemented in P0. Use --dry-run." >&2
  exit 2
fi

root="$(collie_root)"
cd "$root"
current="$(tr -d '[:space:]' < collie/UPSTREAM)"

echo "Fetching upstream tags..." >&2
git fetch upstream --tags --quiet

newest="$(git tag -l 'v*' | grep -v canary | sort -V | tail -n 1)"
[ -n "$newest" ] || { echo "sync-upstream: no release tag found." >&2; exit 1; }

date_str="$(date +%Y-%m-%d)"
mkdir -p collie/reports
report_file="collie/reports/sync-${newest}-${date_str}.md"

tmp=""
cleanup() {
  if [ -n "$tmp" ] && [ -d "$tmp" ]; then
    git worktree remove --force "$tmp/wt" >/dev/null 2>&1 || true
    git worktree prune >/dev/null 2>&1 || true
    rm -rf "$tmp"
  fi
}
trap cleanup EXIT

# Print the FORK.md entry for a file, or "no FORK.md entry".
annotate() {
  local entry
  entry="$(collie_ledger_rows FORK.md | awk -F'\t' -v f="$1" '$1 == f { print "why: " $2 "; upstream PR: " $3 "; status: " $4 }')"
  printf '%s' "${entry:-no FORK.md entry}"
}

report() {
  echo "# Sync report: $current -> $newest"
  echo
  echo "- Date: $date_str"
  echo "- Base: \`collie\` at $(git rev-parse --short HEAD)"
  echo "- Current upstream tag: \`$current\`"
  echo "- Newest release tag: \`$newest\`"
  echo
  if [ "$(printf '%s\n%s\n' "$current" "$newest" | sort -V | tail -n 1)" = "$current" ]; then
    echo "Result: already at newest release. Nothing to merge."
    return 0
  fi

  tmp="$(mktemp -d)"
  git worktree add --detach --quiet "$tmp/wt" HEAD
  local merge_rc=0
  git -C "$tmp/wt" -c rerere.enabled=false -c user.name=collie-sync \
    -c user.email=collie-sync@invalid merge --no-commit --no-ff "$newest" \
    >"$tmp/merge.log" 2>&1 || merge_rc=$?

  local conflicts staged
  conflicts="$(git -C "$tmp/wt" diff --name-only --diff-filter=U)"
  staged="$(git -C "$tmp/wt" diff --cached --name-only | wc -l | tr -d ' ')"

  if [ -z "$conflicts" ] && [ "$merge_rc" -eq 0 ]; then
    echo "Result: CLEAN. The merge has no conflicts ($staged files change)."
    return 0
  fi
  if [ -z "$conflicts" ]; then
    echo "Result: merge failed without a file conflict. Log:"
    echo
    echo '```'
    cat "$tmp/merge.log"
    echo '```'
    return 0
  fi
  local n
  n="$(printf '%s\n' "$conflicts" | wc -l | tr -d ' ')"
  echo "Result: CONFLICTS in $n file(s). $staged other files merge clean."
  echo
  echo "| File | FORK.md entry |"
  echo "|---|---|"
  while IFS= read -r f; do
    echo "| \`$f\` | $(annotate "$f") |"
  done <<<"$conflicts"
}

# Run in this shell (not in a pipe), so the cleanup trap sees $tmp.
report >"$report_file.part"
cleanup
tmp=""
mv "$report_file.part" "$report_file"
cat "$report_file"
echo >&2
echo "Report written to $report_file" >&2
