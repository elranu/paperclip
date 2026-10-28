# FORK.md

This file is the conflict map of the Collie fork.

## Purpose

This repository is a fork of Paperclip (`paperclipai/paperclip`).
Our main branch is `collie`. It starts from an upstream release tag.
The tag is in `collie/UPSTREAM`.

We keep our changes small and easy to find. This file lists each
upstream file that our branch changes. A check fails a PR when it
changes an upstream file that is not listed here.

## Zones

| Zone | What | Conflict risk |
|---|---|---|
| Green | Our own paths: `collie/`, `FORK.md`, `.github/workflows/collie-fork-guard.yml`. | None |
| Yellow | A small number of upstream files where we plug in our code, for example a workspace list or a plugin registry. | Small. Each file is in the ledger. |
| Red | Fixes to the logic of the Paperclip core. One commit per fix. Each fix has a PR to upstream. When upstream merges an equivalent fix, we remove ours. | Medium. Each file is in the ledger. |

Put in the green zone all that you can.

## Ledger

New files under our green paths are not listed. They cannot conflict.
For example, `.github/workflows/collie-fork-guard.yml` is our own new file.
It is green and it is not listed.

Only upstream files that we change are listed. There are none yet.

"Hot" means that the file changed in 2 of the last 3 upstream releases.
A hot file is a probable conflict.

| Zone | Upstream file | Why | Upstream PR | Status | Hot |
|---|---|---|---|---|---|
| - | none yet | - | - | - | - |

To add a row, put the file path in the second column.
You can wrap the path in backticks.

## Inherited workflows

The fork has the GitHub workflows of upstream. They do not work on the fork.
For example, `pr.yml` runs the CI of the upstream `master` on our older tag.
That CI looks for files that our tag does not have yet.

The owner decided on 2026-10-27 that the inherited workflows stay disabled.
Only our own workflows (`collie-*.yml`) run. These are disabled in the
Actions settings: `PR` (`pr.yml`), `commitperclip PR Review`
(`commitperclip-review.yml`) and `CI profile` (`ci-profile.yml`).

Other inherited workflows are not active yet. They start on a push to the
`master` of the fork, or on a push of an upstream tag (`v*`). Some of them
publish (a release, a Docker image). So:

- Do not update the `master` of the fork on GitHub. Do not use
  `gh repo sync` or "Sync fork", and do not push `master`.
- Do not push upstream tags to the fork. The fork guard fetches the tag
  from upstream.
- Sync with an upstream release tag through a PR into `collie`
  (`collie/scripts/sync-upstream.sh`).
- After each sync PR, run `gh workflow list --all`. If an inherited
  workflow ran, disable it with `gh workflow disable` and say so in the PR.
