# Run Paperclip from source (Collie fork)

Target: port 3200, `authenticated` mode (login), telemetry off, data inside
the repository in a folder that git ignores.

## Settings and where the source reads them

| Need | Variable | Source |
|---|---|---|
| Move data folder | `PAPERCLIP_HOME` (default `~/.paperclip`) | `packages/shared/src/home-paths.ts:17-19` |
| Instance name | `PAPERCLIP_INSTANCE_ID` (letters, digits, `_`, `-`) | `packages/shared/src/home-paths.ts:23` |
| Instance folder | `$PAPERCLIP_HOME/instances/$PAPERCLIP_INSTANCE_ID` | `packages/shared/src/home-paths.ts:38` |
| Port | `PORT` (default 3100) | `server/src/config.ts:321` |
| No login | `PAPERCLIP_DEPLOYMENT_MODE=local_trusted` (also the default) | `server/src/config-file.ts:52-56` |
| Local only | `PAPERCLIP_BIND=loopback` | `server/src/config.ts:189` |
| Telemetry off | `PAPERCLIP_TELEMETRY_DISABLED=1` or `DO_NOT_TRACK=1` (value must be `1`) | `packages/shared/src/telemetry/config.ts:71-76` |

Telemetry check: `server/src/index.ts:226` calls `initTelemetry` once, before
the server starts. `server/src/telemetry.ts:15-16` returns without a client when
the config is off, so nothing is sent.

Data folder: upstream `.gitignore` line 21 ignores `.paperclip/` at any depth.
So `PAPERCLIP_HOME=<repo>/.paperclip` stays out of git. No other path is needed.
With no `DATABASE_URL`, Paperclip uses embedded PGlite in that folder.

## Prerequisites

- Node 26.10.0 (the repository needs Node >= 24.11.0) and pnpm 9.15.4.
- pnpm is not on PATH by default. Use:
  `export PATH=$HOME/.local/share/mise/installs/node/26.10.0/bin:$PATH`
- `pnpm install --frozen-lockfile` passes.
- Full `pnpm build` fails without `cargo`: `packages/paperclip-runner` builds a
  Rust binary (`cargo build --release ... paperclip-runnerd`). The server
  `build` script also runs this step. Source mode does not need this build.
  The `paperclip_runner` adapter needs the binary. Do not use it until you
  install Rust (`rustup`) and run `pnpm build`.

## Deployment mode

Use `collie/scripts/start.sh --mode local_trusted|authenticated`. Default: `authenticated`.
The script reads `collie/config/collie.env` (else the example file), sets the
instance variables, and runs `pnpm dev:once`.

**authenticated (recommended).** In `local_trusted`, every local request without
a token is the board (`server/src/middleware/auth.ts:231-239`, and
`board-mutation-guard.ts:88-99` lets it mutate). An agent on the same machine
could then approve its own hire. In `authenticated` mode the board needs a
login session or a board API key.

- Script sets: `BETTER_AUTH_SECRET` (needed by `server/src/auth/better-auth.ts:245`),
  `PAPERCLIP_RUNNER_BINARY=/nonexistent/paperclip-runnerd` (skips the Rust build).
  Bind: `pnpm dev:once --bind custom --bind-host 127.0.0.1`.
  `scripts/dev-runner.ts` removes `PAPERCLIP_DEPLOYMENT_MODE` from the environment
  and sets authenticated/private only when a `--bind` flag is present.
  `--bind loopback` gives `local_trusted`, so do not use it here.
- Secret: if `BETTER_AUTH_SECRET` is not set, the script makes a random value in
  `<instance folder>/auth-secret` (mode 600, git ignores `.paperclip/`). It never prints it.
- A fresh authenticated instance reports `bootstrapStatus: bootstrap_pending`.
  Create the first-admin invite with the same environment:
  `pnpm paperclipai auth bootstrap-ceo`. Open the printed URL in your browser
  and make the board login. Do not first start in `local_trusted` on the same
  instance: it creates the user `local-board` as admin and the invite is not offered.
- Board writes from `bootstrap.sh`: a browser session needs a trusted `Origin`.
  A board API key does not (`board-mutation-guard.ts:88-99`). So the owner gives
  `PAPERCLIP_API_KEY` (board key from `pnpm paperclipai auth login`, which the
  owner approves in the browser). The script sends it as `Authorization: Bearer`.

**local_trusted (smoke test only).** No login. On a fresh instance the script
starts once without the native runner, sets `enableNativeRunner=false`, stops, and
starts again (see "Native runner" below). Do not give agents real work in this mode.

### Order at 9:00

1. Owner decisions.
2. Yes to commit and push.
3. Push branch `collie`.
4. `sudo bash collie/scripts/isolation/setup-collie-user.sh --dry-run`, then the same with sudo and no flag.
5. Logins as `collie` (Claude, Codex, `gh`): the script prints the steps.
   The owner opens each login URL in their own browser.
6. As `collie`: `collie/scripts/start.sh --mode authenticated`.
7. Owner runs `pnpm paperclipai auth bootstrap-ceo`, opens the URL, and makes the board login.
8. As `ranu`, not as `collie`, with `PAPERCLIP_HOME=/home/ranu/repos/paperclip/.paperclip`:
   `pnpm paperclipai auth login` (the owner approves it in the browser). The CLI
   stores the board key in `$PAPERCLIP_HOME/auth.json` (`cli/src/config/home.ts:35-37`).
   `/home/ranu` has mode 700, so `collie` and its agents cannot read the key.
9. As `ranu`: `PAPERCLIP_API_KEY=<key> collie/scripts/bootstrap.sh` (use `--dry-run` first).
   It sets `enableNativeRunner=false`, `enableIsolatedWorkspaces` and
   `enableIsolatedWorkspacesByDefault` (one git worktree for each task), and
   `requireBoardApprovalForNewAgents` on each company.
10. As `ranu`: `pnpm paperclipai auth logout`. This revokes the key on the server
    (`POST /api/cli-auth/revoke-current`) and removes the local copy. After this
    step, no board key exists. With isolation option (a) or (b), this step is mandatory.

Never export the board key in `start.sh` or in the server environment. The agents
are child processes of the server, so they get its environment.

Use a fresh instance for the authenticated mode. A first start in `local_trusted`
makes `local-board` the instance admin, and the first-admin screen never shows after that.
Delete the smoke-test instances in the repo after the live instance works.

## Run as ranu (smoke test)

```sh
cd /home/ranu/repos/paperclip
export PATH=$HOME/.local/share/mise/installs/node/26.10.0/bin:$PATH
export PAPERCLIP_HOME="$PWD/.paperclip"
export PAPERCLIP_INSTANCE_ID=collie
export PAPERCLIP_DEPLOYMENT_MODE=local_trusted
export PAPERCLIP_BIND=loopback
export PAPERCLIP_TELEMETRY_DISABLED=1
export DO_NOT_TRACK=1
export PORT=3200
pnpm dev:once
```

Check: `curl http://localhost:3200/api/health`, then open `http://localhost:3200`.
Stop with Ctrl-C. Reset: delete `.paperclip/instances/collie`.

Do not give agents real work as `ranu`. Agents run full-auto as the OS user and
reach the `gh`, `pass` and CLI logins of `ranu`. Use this mode for a smoke test only.

## Run as user collie

First run `collie/scripts/isolation/setup-collie-user.sh` and do its manual
steps (see `collie/scripts/isolation/README.md`).

```sh
sudo -iu collie
cd ~/paperclip
collie/scripts/start.sh --mode authenticated
```

`start.sh` sets the telemetry, bind and port values itself. See "Deployment mode".

## Agent safety settings

- `claude_local` skips permission prompts by default
  (`packages/adapters/claude-local/src/server/execute.ts:440`, default `true`;
  flag added at `packages/adapters/claude-local/src/server/permissions.ts:12`).
  To turn it off for one agent, set `dangerouslySkipPermissions` to `false` in
  the agent adapter config (UI field:
  `ui/src/adapters/claude-local/config-fields.tsx:247`). A non-interactive run
  then waits for approvals that nobody gives. Use OS isolation as the main guard.
- The heartbeat timer is off for a new agent. `parseHeartbeatPolicy` uses
  `enabled` default `false` and `intervalSec` default `0`
  (`server/src/services/heartbeat/queue.ts:396-397`). The new-agent form also
  sends `heartbeatEnabled: false` (`ui/src/components/agent-config-defaults.ts:29`).

## Native runner (Rust) on a fresh instance

Upstream sets `enableNativeRunner: true` by default. Then `pnpm dev:once` tries
to build the Rust binary `paperclip-runnerd`, and it fails when `cargo` is not
installed. The adapters `claude_local` and `codex_local` do not need this
binary. On the first start only, do these steps:

1. Start once with `PAPERCLIP_RUNNER_BINARY=/nonexistent/paperclip-runnerd`
   added to the environment. This skips the build.
2. Turn the native runner off:
   `curl -X PATCH localhost:3200/api/instance/settings/experimental -H 'content-type: application/json' -d '{"enableNativeRunner":false}'`
3. Stop the server and start it again without `PAPERCLIP_RUNNER_BINARY`.

The setting is stored in the instance database. Later starts need no extra step.
To use the native runner, install Rust (`rustup` writes `~/.cargo`) first.
