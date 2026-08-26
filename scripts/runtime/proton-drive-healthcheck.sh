#!/usr/bin/env bash
# Health-check périodique (toutes les 15 min via proton-drive-healthcheck.timer) :
# détecte un mount mort, un cache VFS anormalement gros, ou des erreurs
# répétées dans le log rclone — puis alerte au lieu d'échouer en silence.
set -uo pipefail

MOUNT="$HOME/ProtonDrive"
LOG="$HOME/.local/state/rclone-protondrive.log"
NOTIFY="$HOME/git/proton-drive-iac/scripts/runtime/proton-drive-notify-failure.sh"
CACHE_DIR="$HOME/.cache/rclone/vfs/protondrive"
MAX_CACHE_BYTES=$((6 * 1024 * 1024 * 1024)) # 6G — marge au-dessus du --vfs-cache-max-size de 5G
STATE_DIR="$HOME/.local/state"
mkdir -p "$STATE_DIR"

fail() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] HEALTHCHECK FAIL: $1" >> "$STATE_DIR/proton-drive-failures.log"
    "$NOTIFY" "$1" 2>/dev/null || true
    exit 1
}

mountpoint -q "$MOUNT" || fail "point de montage $MOUNT inactif"

timeout 10 ls "$MOUNT" >/dev/null 2>&1 || fail "montage bloqué (ls timeout après 10s)"

if [ -d "$CACHE_DIR" ]; then
    size=$(du -sb "$CACHE_DIR" 2>/dev/null | cut -f1)
    if [ -n "${size:-}" ] && [ "$size" -gt "$MAX_CACHE_BYTES" ]; then
        fail "cache VFS anormalement gros (${size} octets > seuil ${MAX_CACHE_BYTES})"
    fi
fi

if [ -f "$LOG" ]; then
    recent_errors=$(tail -n 200 "$LOG" | grep -c "ERROR" || true)
    if [ "$recent_errors" -gt 10 ]; then
        fail "$recent_errors erreurs ERROR dans les 200 dernières lignes du log rclone"
    fi
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] OK" >> "$STATE_DIR/proton-drive-healthcheck.log"
