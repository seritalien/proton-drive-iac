#!/usr/bin/env bash
# 40-encrypt-config.sh — chiffre le fichier rclone.conf avec le mot de passe
# généré et scellé en 20-setup-secret.sh. Idempotent : ne fait rien si la
# config est déjà chiffrée.
#
# Le mot de passe manipulé ici est celui que NOUS avons généré (openssl
# rand), jamais les identifiants Proton — le piper à rclone est donc sans
# risque, contrairement à une authentification Proton qui doit rester
# manuelle (cf. 30-check-remote-auth.sh).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
source ./lib.sh

CONF="$HOME/.config/rclone/rclone.conf"
[ -f "$CONF" ] || die "rclone.conf introuvable — lance d'abord l'authentification (30-check-remote-auth.sh)"
[ -f "$CONFIG_PASS_FILE" ] || die "mot de passe de config absent — lance d'abord 20-setup-secret.sh"

if ! grep -q "^\[$RCLONE_REMOTE\]" "$CONF" 2>/dev/null; then
    log "rclone.conf déjà chiffré — rien à faire"
    exit 0
fi

log "chiffrement de rclone.conf avec le mot de passe généré"
PASS="$(cat "$CONFIG_PASS_FILE")"
printf '%s\n%s\n' "$PASS" "$PASS" | rclone config encryption set
unset PASS

grep -q "^\[$RCLONE_REMOTE\]" "$CONF" 2>/dev/null && die "rclone.conf toujours en clair après tentative de chiffrement"
log "rclone.conf chiffré avec succès"
