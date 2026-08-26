#!/usr/bin/env bash
# cli/00-install-cli.sh — installe le CLI officiel proton-drive (binaire
# portable, pas de sudo/dpkg requis). Version épinglée + vérification
# SHA-512 plutôt qu'un "latest" non versionné : reproductible, pas de
# surprise si Proton publie une version cassée.
#
# Pour mettre à jour : https://proton.me/download/drive/cli/index.html
# donne la dernière version, son URL exacte et son SHA-512.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=../lib.sh
source ./lib.sh
set -e

PROTON_CLI_VERSION="0.8.0"
PROTON_CLI_SHA512="cf61c2688c45e1055d8add6221d9471a5a5b64bf3bcdb86460f5cb18414596cc4df3cdb6627c9097c94bec32a3c9915ada3211ef2ae5be33c46ebbc996ccaa28"
PROTON_CLI_URL="https://proton.me/download/drive/cli/${PROTON_CLI_VERSION}/linux-x64/proton-drive"
PROTON_CLI_INSTALL_DIR="$HOME/.local/bin"

if command -v proton-drive &>/dev/null; then
    log "CLI officiel proton-drive déjà installé ($(proton-drive version 2>/dev/null | head -1)) — rien à faire"
    exit 0
fi

log "CLI officiel proton-drive absent — installation v${PROTON_CLI_VERSION}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/proton-drive" "$PROTON_CLI_URL"
echo "${PROTON_CLI_SHA512}  $tmp/proton-drive" | sha512sum -c - \
    || die "somme de contrôle invalide pour le binaire téléchargé — abandon (voir https://proton.me/download/drive/cli/index.html pour la version courante)"

mkdir -p "$PROTON_CLI_INSTALL_DIR"
install -m 755 "$tmp/proton-drive" "$PROTON_CLI_INSTALL_DIR/proton-drive"

command -v proton-drive &>/dev/null || die "$PROTON_CLI_INSTALL_DIR n'est pas dans le PATH (voir lib.sh)"
log "CLI officiel installé: $(proton-drive version 2>/dev/null | head -1)"
