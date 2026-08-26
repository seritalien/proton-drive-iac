#!/usr/bin/env bash
# 50-verify-connection.sh — vérifie que rclone peut lister le contenu du
# remote protondrive de façon non-interactive, via le password-command.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
source ./lib.sh

PASS_CMD="$HOME/git/proton-drive-iac/scripts/runtime/proton-drive-config-pass.sh"
chmod +x "$PASS_CMD"

log "test de connexion au remote '$RCLONE_REMOTE'..."
rclone lsd "$RCLONE_REMOTE:" --password-command "$PASS_CMD" \
    || die "connexion au remote '$RCLONE_REMOTE' impossible — vérifie l'authentification (rclone config)"

log "connexion OK"
