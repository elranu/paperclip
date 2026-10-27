# Collie

Collie is a holding of agent companies. It runs on a fork of Paperclip.

This folder is our layer on top of Paperclip. It is not a rebrand.
We do not rename Paperclip. We keep our code, configuration, scripts
and docs here, so that upstream releases merge without conflicts.

The conflict map is in `../FORK.md`.

## Branch model

- `master` mirrors the upstream `master`. Never commit to it.
  Update it with `gh repo sync elranu/paperclip -b master`.
- `collie` is our main branch. It starts from an upstream release tag.
  The tag is in `collie/UPSTREAM`.
- Work branches start from `collie` and come back through a PR.
- Sync only with upstream release tags. Never sync with the upstream `master`.
- Git `rerere` is on, so git reuses each conflict resolution.

A CI check (`.github/workflows/collie-fork-guard.yml`) fails a PR into
`collie` when it changes an upstream file that is not in `FORK.md`.

## Folder map

| Path | Content |
|---|---|
| `UPSTREAM` | The upstream release tag that `collie` is based on. |
| `config/` | Configuration as data. `collie.env.example` is the template. |
| `scripts/` | Fork scripts (see below). |
| `scripts/lib/` | Shared shell helpers for the scripts. |
| `docs/` | Our docs. |
| `reports/` | Sync reports. Git ignores this folder. |

## Scripts

Run all scripts from any folder inside the repository.

- `collie/scripts/check-fork.sh [--working-tree]`
  Fails when a changed upstream file is not in the `FORK.md` ledger.
  With `--working-tree`, it also checks uncommitted and untracked files.
- `collie/scripts/sync-upstream.sh --dry-run`
  Finds the newest upstream release tag. If it is newer than
  `collie/UPSTREAM`, it does a trial merge in a temporary worktree and
  writes a report to `collie/reports/`. It never changes your working tree.
  Without `--dry-run`, it exits with code 2 (not implemented in P0).
- `collie/scripts/bootstrap.sh [--dry-run]`
  Run it after the first start. It sets `requireBoardApprovalForNewAgents`
  to `true` in every company. Set `PAPERCLIP_URL` (default
  `http://localhost:3200`). Set `PAPERCLIP_API_KEY` to a board API key
  when the server needs one. In `local_trusted` mode no key is needed.

## Configuration

Copy `config/collie.env.example` to `config/collie.env` and edit it.
Git ignores `*.env` files and `companies.local.*` files in `config/`.
