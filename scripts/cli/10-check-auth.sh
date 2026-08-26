#!/usr/bin/env bash
# cli/10-check-auth.sh — vérifie si le CLI officiel proton-drive est
# authentifié. Si non : instructions manuelles (même règle que pour rclone
# — jamais d'identifiants Proton via un outil piloté par un assistant IA),
# puis exit 10.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=../lib.sh
source ./lib.sh

if proton_drive_locked filesystem list / &>/dev/null; then
    log "CLI officiel proton-drive: authentifié"
    exit 0
fi

cat <<EOF

════════════════════════════════════════════════════════════════════
  ÉTAPE MANUELLE REQUISE — authentification CLI officiel Proton Drive
════════════════════════════════════════════════════════════════════

Lance TOI-MÊME, dans un terminal :

    proton-drive auth login

Une fois authentifié, relance ce script pour continuer.
════════════════════════════════════════════════════════════════════

EOF
exit 10
