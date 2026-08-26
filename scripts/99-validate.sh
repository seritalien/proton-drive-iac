#!/usr/bin/env bash
# 99-validate.sh — validation bout-en-bout : mount actif, écriture/lecture
# aller-retour (upload + download réels via le mount), aucun secret en clair.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
source ./lib.sh

log "vérification du point de montage..."
mountpoint -q "$PROTON_MOUNT" || die "$PROTON_MOUNT n'est pas monté"
log "OK: $PROTON_MOUNT est monté"

log "test d'écriture/lecture (upload + download réels via le mount)..."
TESTFILE="$PROTON_MOUNT/_validation_iac_$(date +%s).txt"
CONTENT="proton-drive-iac-validation-$(hostname)-$(date +%Y%m%d-%H%M%S)"
echo "$CONTENT" > "$TESTFILE"
sync
READBACK="$(cat "$TESTFILE")"
[ "$READBACK" = "$CONTENT" ] || die "le contenu relu ne correspond pas à ce qui a été écrit"
log "OK: écriture/lecture cohérente ($TESTFILE)"
log "Fichier laissé en place 10s pour vérification visuelle multi-appareils (mobile/autre PC)..."
sleep 10
rm -f "$TESTFILE"
log "fichier de test supprimé"

log "vérification: aucun secret en clair sur disque..."
CONF="$HOME/.config/rclone/rclone.conf"
if [ -f "$CONF" ] && grep -q "^\[$RCLONE_REMOTE\]" "$CONF" 2>/dev/null; then
    die "rclone.conf est TOUJOURS EN CLAIR — le chiffrement (40-encrypt-config.sh) n'a pas été appliqué"
fi
log "OK: rclone.conf n'est pas en clair"

log "vérification: le health-check passe..."
bash ./runtime/proton-drive-healthcheck.sh
tail -1 "$XDG_STATE_HOME/proton-drive-healthcheck.log"

log "=== VALIDATION COMPLÈTE: le mount Proton Drive fonctionne dans les deux sens ==="
