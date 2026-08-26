#!/usr/bin/env bash
# 20-setup-secret.sh — génère (une seule fois) un mot de passe de config
# rclone fort, stocké dans un fichier chmod 600.
#
# Repli documenté : systemd-creds (--with-key=host) serait plus robuste
# (secret lié à la machine, jamais en clair même dans un fichier) mais
# nécessite root pour `systemd-creds setup` et pour le déchiffrement au
# démarrage du service (ce qui imposerait une unit système, pas --user).
# Cette machine n'a pas de TPM et aucun TTY sudo n'est disponible dans cet
# environnement d'installation automatisée — voir README.md pour la
# procédure de montée en robustesse si ça change.
#
# Idempotent : si le fichier existe déjà, ne le régénère pas (le
# régénérer sans ré-encoder la config rclone existante la rendrait
# irrécupérable).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
source ./lib.sh

if [ -f "$CONFIG_PASS_FILE" ]; then
    log "mot de passe de config déjà présent ($CONFIG_PASS_FILE) — rien à faire"
    exit 0
fi

mkdir -p "$(dirname "$CONFIG_PASS_FILE")"
chmod 700 "$(dirname "$CONFIG_PASS_FILE")"

log "génération d'un mot de passe de config rclone (32o aléatoires, base64)"
openssl rand -base64 32 > "$CONFIG_PASS_FILE"
chmod 600 "$CONFIG_PASS_FILE"

log "mot de passe généré: $CONFIG_PASS_FILE (chmod 600, lisible uniquement par $(whoami))"
