#!/usr/bin/env bash
# 95-decommission-onedrive.sh — étape finale : retire le client de sync
# OneDrive Microsoft de la machine, une fois Proton Drive validé comme
# fonctionnel dans les deux sens (99-validate.sh doit avoir réussi avant
# d'en arriver là).
#
# IMPORTANT — périmètre volontairement limité : ce script désinstalle le
# CLIENT DE SYNC local. Il ne touche JAMAIS aux données réellement stockées
# sur le compte Microsoft OneDrive cloud (ça, c'est une décision séparée et
# volontairement plus lourde de conséquences — à faire toi-même depuis
# onedrive.live.com si tu le souhaites un jour).
#
# AVERTISSEMENT : si tu migres manuellement des fichiers hors de ~/OneDrive
# (ex. vers ~/ProtonDrive) PENDANT que le client de sync OneDrive tourne
# encore, celui-ci peut interpréter le dossier local vidé comme une
# suppression à répercuter sur le cloud Microsoft — avec un risque réel de
# perte de données côté cloud si son garde-fou anti-suppression-massive ne
# suffit pas à tout bloquer. Désactive/stoppe onedrive.service AVANT toute
# migration manuelle de ce type, pas après.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
source ./lib.sh

log "arrêt et masquage du service onedrive (empêche toute réactivation accidentelle)"
systemctl --user stop onedrive.service 2>/dev/null || true
systemctl --user disable onedrive.service 2>/dev/null || true
systemctl --user mask onedrive.service 2>/dev/null || true

BACKUP_DIR="$HOME/.local/state/onedrive-decommission-backup-$(date +%Y%m%d)"
if [ -d "$HOME/.config/onedrive" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$HOME/.config/onedrive" "$BACKUP_DIR/config-onedrive"
    log "config/état du client onedrive archivé dans $BACKUP_DIR/config-onedrive (contient le refresh_token — pas supprimé, juste déplacé)"
fi

if command -v onedrive &>/dev/null; then
    log "désinstallation du paquet onedrive"
    sudo apt-get remove -y onedrive
else
    log "paquet onedrive déjà absent"
fi

if [ -d "$HOME/OneDrive" ] && [ -z "$(ls -A "$HOME/OneDrive" 2>/dev/null)" ]; then
    rmdir "$HOME/OneDrive"
    log "dossier ~/OneDrive local vide supprimé"
else
    # shellcheck disable=SC2088 # texte affiché littéralement, pas un chemin à faire expandre
    log "~/OneDrive local non vide ou absent — laissé en l'état, à vérifier manuellement"
fi

cat <<EOF

════════════════════════════════════════════════════════════════════
  Décommissionnement du client OneDrive terminé.

  CE QUI N'A PAS ÉTÉ TOUCHÉ : les données restantes sur le compte
  Microsoft OneDrive cloud lui-même. Si tu veux les supprimer
  définitivement du cloud Microsoft aussi, c'est une action séparée à
  faire toi-même sur onedrive.live.com — ce script ne l'automatise pas.
════════════════════════════════════════════════════════════════════

EOF
