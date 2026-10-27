# Isolation: run Paperclip as the Linux user `collie`

## Why

Paperclip agents run full-auto. The `claude_local` adapter passes
`--dangerously-skip-permissions` by default
(`packages/adapters/claude-local/src/server/execute.ts:440`). An agent runs
with the rights of the OS user that started the server.

If the server runs as `ranu`, an agent can reach everything `ranu` can reach:

- the `gh` login and its token,
- the `pass` store,
- the logins of other CLIs (Claude, Codex, cloud tools),
- all files in `/home/ranu`.

User `collie` has none of these. It has no sudo rights, its own home, and only
the logins that you give it by hand. Its GitHub token covers one repository.

## What the script does

`setup-collie-user.sh` (run with sudo, safe to run again):

1. Creates user `collie` (no sudo group, locked password, home mode 700).
2. Installs mise, Node 26.10.0 and pnpm 9.15.4 for `collie`.
3. Clones `https://github.com/elranu/paperclip` (branch `collie`) to `/home/collie/paperclip`.
4. Copies `collie/config/collie.env.example` to `.env`.
5. Runs `pnpm install --frozen-lockfile`.

The script never reads or copies a secret from `ranu`.

Test first: `bash collie/scripts/isolation/setup-collie-user.sh --dry-run`

## Owner checklist (20 to 30 minutes)

1. Read the dry run (2 min).
2. Run `sudo bash collie/scripts/isolation/setup-collie-user.sh` (5 to 10 min).
3. `sudo -iu collie claude` : log in with the account for this work (3 min).
4. `sudo -iu collie codex login` (3 min).
5. On github.com create a fine-grained token (5 min):
   - Repository access: only `elranu/paperclip`.
   - Permissions: Contents read/write, Pull requests read/write, Metadata read.
   - Short expiry (30 days).
6. `sudo -iu collie gh auth login --with-token`, paste the token, Enter, Ctrl-D.
7. `sudo -iu collie gh auth status` : confirm one account and one repository.
8. Check isolation: `sudo -iu collie ls /home/ranu` must say "Permission denied".
9. Start Paperclip: see `collie/docs/RUNNING.md`, section "Run as user collie".

## Build note

`pnpm build` needs the Rust toolchain (`cargo`) for the `paperclip-runner`
binary. Source mode (`pnpm dev:once`) does not run that step. See
`collie/docs/RUNNING.md`.
