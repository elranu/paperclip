#!/usr/bin/env bash
# Run after the first start. First it sets the instance flags (no native
# runner, isolated workspaces). Then it sets requireBoardApprovalForNewAgents=true
# on every company.
# Usage: bootstrap.sh [--dry-run]
# Env:   PAPERCLIP_URL      server URL (default http://localhost:3200)
#        PAPERCLIP_API_KEY  board API key. Not needed in local_trusted mode.
#                           Needed in authenticated mode (see collie/docs/RUNNING.md).
set -euo pipefail

dry_run=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    -h|--help) sed -n '2,9p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "bootstrap: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

url="${PAPERCLIP_URL:-http://localhost:3200}"
url="${url%/}"
key="${PAPERCLIP_API_KEY:-}"

auth=()
if [ -n "$key" ]; then
  auth=(-H "Authorization: Bearer $key")
fi

body='{"requireBoardApprovalForNewAgents":true}'
# enableIsolatedWorkspaces shows the workspace controls. enableIsolatedWorkspacesByDefault
# makes a project without its own policy give each task a git worktree
# (server/src/services/heartbeat.ts:2387; packages/shared/src/feature-catalog.ts:85).
# Without it, agents share one checkout and can overwrite each other.
instance_body='{"enableNativeRunner":false,"enableIsolatedWorkspaces":true,"enableIsolatedWorkspacesByDefault":true}'

if [ "$dry_run" -eq 1 ]; then
  echo "bootstrap (dry run). No call is made."
  echo "PATCH $url/api/instance/settings/experimental   body: $instance_body"
  echo "GET   $url/api/companies"
  echo "PATCH $url/api/companies/<companyId>   body: $body"
  [ -n "$key" ] && echo "(with header: Authorization: Bearer ***)" || echo "(no API key: works in local_trusted mode only)"
  exit 0
fi

# A board API key skips the browser-origin check, so no Origin header is needed
# (server/src/middleware/board-mutation-guard.ts:88-99).
curl -fsS -X PATCH "${auth[@]}" -H 'Content-Type: application/json' \
  -d "$instance_body" "$url/api/instance/settings/experimental" >/dev/null
echo "bootstrap: set instance flags: $instance_body"

# The route GET /api/companies is board-only: server/src/routes/companies.ts.
companies="$(curl -fsS "${auth[@]}" "$url/api/companies")"
ids="$(printf '%s' "$companies" | node -e '
  let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
    for (const c of JSON.parse(s)) console.log(c.id + "\t" + (c.name || ""));
  });')"

if [ -z "$ids" ]; then
  echo "bootstrap: no companies found. Nothing to do."
  exit 0
fi

while IFS=$'\t' read -r id name; do
  [ -n "$id" ] || continue
  curl -fsS -X PATCH "${auth[@]}" -H 'Content-Type: application/json' \
    -d "$body" "$url/api/companies/$id" >/dev/null
  echo "bootstrap: set requireBoardApprovalForNewAgents=true on $name ($id)"
done <<<"$ids"
