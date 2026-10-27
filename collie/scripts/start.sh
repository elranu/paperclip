#!/usr/bin/env bash
# One-command start of the Collie instance from source.
# Usage: start.sh [--mode local_trusted|authenticated]   (default: authenticated)
# Env:   read from collie/config/collie.env, else collie.env.example.
#        PAPERCLIP_HOME (default <repo>/.paperclip), PAPERCLIP_INSTANCE_ID (default collie).
# local_trusted, fresh instance (no db folder): start once without the native
# runner, set enableNativeRunner=false, stop, then start for real.
# authenticated: no such step. A first start in local_trusted would create the
# user "local-board" as instance admin, and then nobody could claim the first-admin
# screen. Instead the script sets PAPERCLIP_RUNNER_BINARY=/nonexistent/paperclip-runnerd
# (skips the Rust build). bootstrap.sh turns the native runner off later.
# Authenticated mode needs BETTER_AUTH_SECRET. If it is not set, this script
# makes one in <instance folder>/auth-secret (mode 600) and never prints it.
set -euo pipefail

mode=authenticated
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) mode="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "start: unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$mode" in
  local_trusted|authenticated) ;;
  *) echo "start: --mode must be local_trusted or authenticated" >&2; exit 2 ;;
esac

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
cd "$repo"

node_bin="$HOME/.local/share/mise/installs/node/26.10.0/bin"
[ -d "$node_bin" ] && export PATH="$node_bin:$PATH"

envfile="$repo/collie/config/collie.env"
[ -f "$envfile" ] || envfile="$repo/collie/config/collie.env.example"
set -a
# shellcheck disable=SC1090
. "$envfile"
set +a

export PAPERCLIP_HOME="${PAPERCLIP_HOME:-$repo/.paperclip}"
export PAPERCLIP_INSTANCE_ID="${PAPERCLIP_INSTANCE_ID:-collie}"
export PAPERCLIP_BIND=loopback
export PAPERCLIP_TELEMETRY_DISABLED=1
export DO_NOT_TRACK=1
export PORT="${PORT:-3200}"
instance_dir="$PAPERCLIP_HOME/instances/$PAPERCLIP_INSTANCE_ID"
base="http://localhost:$PORT"

wait_health() {
  for _ in $(seq 1 180); do
    curl -fsS "$base/api/health" >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "start: server did not become healthy in 180 s" >&2
  return 1
}

if [ "$mode" = local_trusted ] && [ ! -d "$instance_dir/db" ]; then
  echo "start: fresh instance. First start without the native runner."
  PAPERCLIP_DEPLOYMENT_MODE=local_trusted PAPERCLIP_RUNNER_BINARY=/nonexistent/paperclip-runnerd \
    setsid pnpm dev:once >/dev/null 2>&1 &
  pid=$!
  trap 'kill -- -"$pid" 2>/dev/null || true' EXIT
  wait_health
  curl -fsS -X PATCH "$base/api/instance/settings/experimental" \
    -H 'content-type: application/json' -d '{"enableNativeRunner":false}' >/dev/null
  kill -- -"$pid" 2>/dev/null || true
  trap - EXIT
  for _ in $(seq 1 30); do kill -0 -- -"$pid" 2>/dev/null || break; sleep 1; done
  kill -KILL -- -"$pid" 2>/dev/null || true
  echo "start: native runner is off. Real start now."
fi

if [ "$mode" = authenticated ]; then
  export PAPERCLIP_RUNNER_BINARY="${PAPERCLIP_RUNNER_BINARY:-/nonexistent/paperclip-runnerd}"
  if [ -z "${BETTER_AUTH_SECRET:-}" ]; then
    secret_file="$instance_dir/auth-secret"
    if [ ! -s "$secret_file" ]; then
      mkdir -p "$instance_dir"
      (umask 077; node -e 'process.stdout.write(require("crypto").randomBytes(32).toString("hex"))' >"$secret_file")
    fi
    BETTER_AUTH_SECRET="$(cat "$secret_file")"
    export BETTER_AUTH_SECRET
  fi
fi

echo "start: mode=$mode port=$PORT instance=$PAPERCLIP_INSTANCE_ID"
if [ "$mode" = authenticated ]; then
  # scripts/dev-runner.ts deletes PAPERCLIP_DEPLOYMENT_MODE from the environment.
  # It sets authenticated/private itself when a --bind flag is present.
  # "--bind loopback" would give local_trusted, so use a custom bind on 127.0.0.1.
  exec pnpm dev:once --bind custom --bind-host 127.0.0.1
fi
exec pnpm dev:once
