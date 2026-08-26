#!/usr/bin/env bash
# Appelé par rclone via --password-command : fournit le mot de passe de
# config rclone depuis le fichier chmod 600 (voir 20-setup-secret.sh et
# README.md "Sécurité du secret" pour le contexte du choix).
set -euo pipefail
exec cat "$HOME/.config/proton-drive/rclone-config-pass"
