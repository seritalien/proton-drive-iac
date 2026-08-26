#!/usr/bin/env bash
# install.sh — orchestrateur idempotent de bout en bout.
#
# Peut être relancé autant de fois que nécessaire : chaque étape détecte
# déjà-fait et passe son tour. S'arrête UNIQUEMENT à l'étape
# d'authentification Proton (30), qui doit être faite manuellement par
# l'utilisateur dans son propre terminal (jamais via un outil piloté par
# un assistant IA).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/scripts"

run() {
    echo
    echo "─── $1 ───"
    bash "./$1"
}

run 10-install-dependencies.sh
run 20-setup-secret.sh

set +e
bash ./30-check-remote-auth.sh
auth_status=$?
set -e
if [ "$auth_status" -eq 10 ]; then
    echo
    echo "Installation en pause — authentifie-toi puis relance: ./install.sh"
    exit 10
elif [ "$auth_status" -ne 0 ]; then
    echo "ERREUR inattendue dans 30-check-remote-auth.sh (code $auth_status)" >&2
    exit "$auth_status"
fi

run 40-encrypt-config.sh
run 50-verify-connection.sh
run 60-install-systemd-units.sh
run 99-validate.sh

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Mount natif actif sur ~/ProtonDrive, surveillé."
echo "  Étape suivante (manuelle): scripts/95-decommission-onedrive.sh"
echo "  une fois que tu as confirmé que tout ce qui compte est bien"
echo "  monté/accessible (ce script ne se lance jamais automatiquement)."
echo "═══════════════════════════════════════════════════════════════"
