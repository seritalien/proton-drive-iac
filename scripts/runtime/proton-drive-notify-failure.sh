#!/usr/bin/env bash
# Déclenché par OnFailure= (partagé par plusieurs units : mount rclone,
# sync CLI, health-check) : alerte desktop + trace persistante. Objectif :
# une tâche planifiée sans surveillance peut échouer en silence pendant des
# semaines avant que quiconque ne s'en aperçoive — ce script rend l'échec
# visible immédiatement, systématiquement.
#
# systemd ne transmet pas nativement le nom de l'unit à l'origine d'un
# OnFailure= déclenché ailleurs — on interroge donc --failed pour savoir
# QUOI a échoué, plutôt que d'afficher un message générique inexact.
set -euo pipefail

FAILED_UNITS="$(systemctl --user --failed --plain --no-legend 2>/dev/null | awk '{print $1}' | paste -sd, -)"
REASON="${1:-${FAILED_UNITS:-un service Proton Drive a échoué}}"
STATE_DIR="$HOME/.local/state"
mkdir -p "$STATE_DIR"

MSG="Proton Drive: $REASON ($(date '+%Y-%m-%d %H:%M:%S')). Diagnostic: systemctl --user --failed"
echo "$MSG" >> "$STATE_DIR/proton-drive-failures.log"

export DISPLAY="${DISPLAY:-:0}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
notify-send --urgency=critical "Proton Drive" "$MSG" 2>/dev/null || true
