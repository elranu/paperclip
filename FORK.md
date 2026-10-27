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
