#!/usr/bin/env bash
# scripts/cli/install.sh — chemin de repli : CLI officiel proton-drive,
# actif tant que le mount natif rclone n'est pas disponible (voir
# README.md "État actuel"). Idempotent, s'arrête à l'étape
# d'authentification manuelle comme le pipeline rclone.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

run() {
    echo
    echo "─── cli/$1 ───"
    bash "./$1"
}

set +e
bash ./10-check-auth.sh
auth_status=$?
set -e
if [ "$auth_status" -eq 10 ]; then
    echo
    echo "En pause — authentifie-toi puis relance: scripts/cli/install.sh"
    exit 10
elif [ "$auth_status" -ne 0 ]; then
    echo "ERREUR inattendue dans 10-check-auth.sh (code $auth_status)" >&2
    exit "$auth_status"
fi

run 20-sync-bidirectional.sh

cd ../..
mkdir -p "$HOME/.config/systemd/user"
cp systemd/proton-drive-cli-sync.service "$HOME/.config/systemd/user/"
cp systemd/proton-drive-cli-sync.timer "$HOME/.config/systemd/user/"
cp systemd/proton-drive-failure-notify.service "$HOME/.config/systemd/user/" 2>/dev/null || true
chmod +x scripts/runtime/*.sh
systemctl --user daemon-reload
systemctl --user enable --now proton-drive-cli-sync.timer

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Sync initial terminé, timer quotidien actif (avec alerte"
echo "  desktop en cas d'échec). Vérifie: systemctl --user list-timers | grep proton"
echo
echo "  Étape suivante (manuelle, une fois le sync vérifié complet):"
echo "  ../95-decommission-onedrive.sh"
echo "═══════════════════════════════════════════════════════════════"
