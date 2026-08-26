#!/usr/bin/env bash
# Déclenché par OnFailure= sur proton-drive-mount.service ou par le
# health-check : alerte desktop + trace persistante. Objectif : une tâche
# planifiée sans surveillance peut échouer en silence pendant des semaines
# avant que quiconque ne s'en aperçoive — ce script rend l'échec visible
# immédiatement, systématiquement.
set -euo pipefail

REASON="${1:-Le montage Proton Drive a échoué}"
STATE_DIR="$HOME/.local/state"
mkdir -p "$STATE_DIR"

MSG="Proton Drive: $REASON ($(date '+%Y-%m-%d %H:%M:%S')). Diagnostic: journalctl --user -u proton-drive-mount.service -n 50"
echo "$MSG" >> "$STATE_DIR/proton-drive-failures.log"

export DISPLAY="${DISPLAY:-:0}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
notify-send --urgency=critical "Proton Drive" "$MSG" 2>/dev/null || true
