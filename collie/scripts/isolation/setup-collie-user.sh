#!/usr/bin/env bash
# Create the isolated Linux user "collie" and prepare Paperclip for it.
# The OWNER runs this script with sudo:  sudo bash setup-collie-user.sh [--dry-run]
#
# Rules:
# - The script never reads or copies a secret from any other user.
# - Each step is safe to run again (idempotent).
# - With --dry-run the script prints the steps and changes nothing.
set -euo pipefail

COLLIE_USER="collie"
COLLIE_HOME="/home/${COLLIE_USER}"
REPO_URL="https://github.com/elranu/paperclip"
REPO_BRANCH="collie"
REPO_DIR="${COLLIE_HOME}/paperclip"
NODE_VERSION="26.10.0"
PNPM_VERSION="9.15.4"
# CLI versions that ranu uses (mise installs: claude, codex, gh).
CLAUDE_VERSION="2.1.309"
CODEX_VERSION="0.164.0"
GH_VERSION="2.103.0"
ENV_EXAMPLE="collie/config/collie.env.example"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      echo "Usage: sudo bash $0 [--dry-run]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

say() { echo "==> $*"; }

# run_root CMD...: run a command as root (or print it in dry-run mode).
run_root() {
  echo "    [root] $*"
  if [ "$DRY_RUN" -eq 0 ]; then "$@"; fi
}

# run_collie 'SHELL CODE': run shell code as the collie user with a clean login environment.
run_collie() {
  echo "    [${COLLIE_USER}] $1"
  if [ "$DRY_RUN" -eq 0 ]; then
    sudo -iu "$COLLIE_USER" bash -lc "set -euo pipefail; $1"
  fi
}

if [ "$DRY_RUN" -eq 1 ]; then
  say "Dry run: nothing changes. Commands are printed only."
elif [ "$(id -u)" -ne 0 ]; then
  echo "Run this script with sudo, or use --dry-run." >&2
  exit 1
fi

# Step 1: create the user. No sudo group. Own home. No password (login by sudo -iu only).
say "Step 1: create Linux user '${COLLIE_USER}' (no sudo rights, own home)"
if id "$COLLIE_USER" >/dev/null 2>&1; then
  say "User '${COLLIE_USER}' exists. Skip."
else
  run_root useradd --create-home --home-dir "$COLLIE_HOME" --shell /bin/bash "$COLLIE_USER"
  run_root passwd --lock "$COLLIE_USER"
fi

# Step 2: check that the user has no sudo rights.
say "Step 2: check that '${COLLIE_USER}' is not in a sudo group"
if [ "$DRY_RUN" -eq 0 ] && id -nG "$COLLIE_USER" | tr ' ' '\n' | grep -qxE 'wheel|sudo|admin'; then
  echo "ERROR: '${COLLIE_USER}' is in a sudo group. Remove it: gpasswd -d ${COLLIE_USER} <group>" >&2
  exit 1
fi
say "OK: no sudo group."

# Step 3: close the home folder to other users.
say "Step 3: set mode 700 on ${COLLIE_HOME}"
run_root chmod 700 "$COLLIE_HOME"

# Step 4: install mise, Node and pnpm for the collie user.
say "Step 4: install mise for '${COLLIE_USER}'"
run_collie 'command -v mise >/dev/null 2>&1 || [ -x "$HOME/.local/bin/mise" ] || curl -fsSL https://mise.run | sh'

say "Step 5: install Node ${NODE_VERSION} with mise"
run_collie "export PATH=\"\$HOME/.local/bin:\$PATH\"; mise use --global node@${NODE_VERSION}"

say "Step 6: activate mise in the shell profile of '${COLLIE_USER}'"
run_collie 'grep -q "mise activate" "$HOME/.bashrc" 2>/dev/null || echo '"'"'eval "$($HOME/.local/bin/mise activate bash)"'"'"' >> "$HOME/.bashrc"'

say "Step 7: enable pnpm ${PNPM_VERSION} through corepack"
run_collie "export PATH=\"\$HOME/.local/bin:\$PATH\"; eval \"\$(mise activate bash)\"; corepack enable --install-directory \"\$HOME/.local/bin\" pnpm; corepack prepare pnpm@${PNPM_VERSION} --activate; pnpm --version"

# Step 7b: install the agent CLIs with mise (pinned versions).
say "Step 7b: install claude ${CLAUDE_VERSION}, codex ${CODEX_VERSION}, gh ${GH_VERSION} with mise"
run_collie "export PATH=\"\$HOME/.local/bin:\$PATH\"; eval \"\$(mise activate bash)\"; mise use --global claude@${CLAUDE_VERSION} codex@${CODEX_VERSION} gh@${GH_VERSION}"

# Step 8: clone the fork.
say "Step 8: clone ${REPO_URL} (branch ${REPO_BRANCH}) into ${REPO_DIR}"
run_collie "if [ -d '${REPO_DIR}/.git' ]; then echo 'Clone exists. Skip.'; else git clone --branch '${REPO_BRANCH}' '${REPO_URL}' '${REPO_DIR}'; fi"

# Step 9: copy the env template. Do not overwrite an existing .env.
say "Step 9: copy ${ENV_EXAMPLE} to ${REPO_DIR}/.env (only if .env is missing)"
run_collie "if [ -f '${REPO_DIR}/.env' ]; then echo '.env exists. Skip.'; else cp '${REPO_DIR}/${ENV_EXAMPLE}' '${REPO_DIR}/.env'; chmod 600 '${REPO_DIR}/.env'; fi"

# Step 10: install dependencies.
say "Step 10: install dependencies (frozen lockfile)"
run_collie "export PATH=\"\$HOME/.local/bin:\$PATH\"; eval \"\$(mise activate bash)\"; cd '${REPO_DIR}' && pnpm install --frozen-lockfile"

# Final check: print the CLI versions as the collie user.
say "Final check: CLI versions as '${COLLIE_USER}'"
run_collie "export PATH=\"\$HOME/.local/bin:\$PATH\"; eval \"\$(mise activate bash)\"; claude --version; codex --version; gh --version"

cat <<EOF

==> Automatic steps done. Do these steps BY HAND (they need your browser or your token):

  1. Claude login:       sudo -iu ${COLLIE_USER} claude
                         Claude prints a URL. Open it in your OWN browser, sign in, and paste the code back.
  2. Codex login:        sudo -iu ${COLLIE_USER} codex login --device-auth
                         Codex prints a URL and a code. Open the URL in your OWN browser and enter the code.
  3. GitHub token:       Create a fine-grained token on github.com.
                         Repository access: ONLY elranu/paperclip.
                         Permissions: Contents (read/write), Pull requests (read/write), Metadata (read).
                         Then run:  sudo -iu ${COLLIE_USER} gh auth login --with-token
                         Paste the token, press Enter, then Ctrl-D.
  4. Check the identity: sudo -iu ${COLLIE_USER} gh auth status
  5. Start Paperclip:    see collie/docs/RUNNING.md, section "Deployment mode".

This script did not read or copy any secret from another user.
EOF
