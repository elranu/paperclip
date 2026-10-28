# P0 owner decisions (2026-10-27)

The owner made these decisions at the start of P0.

| Point | Decision |
|---|---|
| Isolation of the agents (plan open point 9.6) | Option (a). The agents run as the OS user `ranu`, in full-auto, as Paperclip starts them. The owner accepts the risk below. |
| Deployment mode | `authenticated`, private exposure, loopback bind. |
| First company | A disposable demo company on a local test repository. |
| Commit and push | Yes for the P0 skeleton: the branch `collie` and the P0 PR. |
| Inherited upstream workflows | Disabled in the fork. Only our own workflows run. See "Inherited workflows" in `FORK.md`. |

## The risk that the owner accepts (option a)

- The `claude_local` adapter starts Claude Code with `--dangerously-skip-permissions`. The default is `dangerouslySkipPermissions: true` (`packages/adapters/claude-local/src/server/execute.ts:440`).
- As `ranu`, an agent can use the `gh` login (push rights on the Basilic repositories), `pass`, the CLI logins, and the files in `~/repos`, including the `.env` files.
- An agent can read and change the instance folder `.paperclip/instances/<id>`: the database, `auth-secret` and the secrets key. With these files, an agent can act as the board.

## Limits for P0 under option (a)

- Use only the disposable demo company. Its workspace is a local test repository with no remote and no secret.
- Do not create a company for Basilic, or for another repository with secrets or push rights, until the owner decides the isolation again.
- Use one CEO on `claude_local` and one small issue. Pause the CEO after the demo.
- Do the bootstrap settings in the web UI with the browser session of the owner. Do not create a board API key. If a board API key is ever needed, revoke it right after use (the CLI command `auth logout` with `--api-base http://localhost:3200`, see `collie/docs/RUNNING.md`), and never keep it in a file or in the server environment.
- Decide the isolation again before the first real company. The recommendation stays option (c), a separate Linux user: `collie/scripts/isolation/setup-collie-user.sh`.
