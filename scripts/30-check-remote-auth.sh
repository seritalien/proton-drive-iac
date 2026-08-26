#!/usr/bin/env bash
# 30-check-remote-auth.sh — vérifie si le remote rclone 'protondrive' est
# déjà configuré et authentifié. Si non : imprime la commande exacte à
# lancer MANUELLEMENT par l'utilisateur (jamais via ce script ni via un
# outil piloté par un LLM — les identifiants Proton + le secret TOTP ne
# doivent jamais transiter par un canal observé par un tiers) puis quitte
# avec le code 10 (utilisé par install.sh pour savoir qu'il doit s'arrêter
# à cette étape et attendre confirmation).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
source ./lib.sh
set -e

remote_configured() {
    local conf="$HOME/.config/rclone/rclone.conf"
    [ -f "$conf" ] || return 1

    # Config en clair (avant chiffrement, Task 40) : lisible directement.
    if grep -q "^\[$RCLONE_REMOTE\]" "$conf" 2>/dev/null; then
        return 0
    fi

    # Config déjà chiffrée (après Task 40) : ne peut se lire qu'avec le
    # mot de passe généré — s'il n'existe pas encore non plus, ce n'est
    # de toute façon pas ce cas de figure.
    if [ -f "$CONFIG_PASS_FILE" ]; then
        rclone listremotes --password-command "$HOME/git/proton-drive-iac/scripts/runtime/proton-drive-config-pass.sh" 2>/dev/null \
            | grep -q "^${RCLONE_REMOTE}:$" && return 0
    fi

    return 1
}

if ! remote_configured; then
    cat <<EOF

════════════════════════════════════════════════════════════════════
  ÉTAPE MANUELLE REQUISE — authentification Proton Drive
════════════════════════════════════════════════════════════════════

Aucun remote '$RCLONE_REMOTE' trouvé. Lance TOI-MÊME, dans un terminal,
la commande suivante (ne la fais PAS exécuter par un assistant IA — tes
identifiants Proton + ton secret TOTP ne doivent jamais transiter par un
canal tiers) :

    rclone config

Puis suis l'assistant :
  - n (new remote)
  - name: $RCLONE_REMOTE
  - Storage: protondrive
  - email + mot de passe de ton compte Proton
  - si 2FA activé : le secret TOTP quand demandé
  - "Edit advanced config?" -> n (sauf besoin spécifique)
  - "y" pour confirmer, "q" pour quitter l'assistant

Une fois terminé, relance l'installation : elle reprendra automatiquement
à partir d'ici (chiffrement de la config, vérification, montage...).
════════════════════════════════════════════════════════════════════

EOF
    exit 10
fi

log "remote '$RCLONE_REMOTE' déjà présent dans rclone.conf"
