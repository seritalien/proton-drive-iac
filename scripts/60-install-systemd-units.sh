#!/usr/bin/env bash
# 60-install-systemd-units.sh — installe (copie) les units systemd --user
# depuis systemd/ vers ~/.config/systemd/user/, puis active mount +
# healthcheck.timer. Idempotent (copie + daemon-reload + enable --now sont
# tous sûrs à ré-exécuter).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
source ./lib.sh

REPO_ROOT="$(cd .. && pwd)"

mkdir -p "$SYSTEMD_USER_DIR"

for unit in proton-drive-mount.service proton-drive-failure-notify.service proton-drive-healthcheck.service proton-drive-healthcheck.timer; do
    cp "$REPO_ROOT/systemd/$unit" "$SYSTEMD_USER_DIR/$unit"
    log "installé: $SYSTEMD_USER_DIR/$unit"
done

chmod +x "$REPO_ROOT/scripts/runtime/"*.sh

# Nettoyage de l'ébauche jamais fonctionnelle de setup-rclone-proton.sh
# (config en clair, jamais activée) si elle traîne encore.
if [ -f "$SYSTEMD_USER_DIR/rclone-protondrive.service" ]; then
    systemctl --user disable --now rclone-protondrive.service 2>/dev/null || true
    rm -f "$SYSTEMD_USER_DIR/rclone-protondrive.service"
    log "ancienne ébauche rclone-protondrive.service supprimée"
fi

systemctl --user daemon-reload
mkdir -p "$PROTON_MOUNT"

systemctl --user enable --now proton-drive-mount.service
systemctl --user enable --now proton-drive-healthcheck.timer

log "units systemd installées et activées"
