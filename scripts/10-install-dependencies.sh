#!/usr/bin/env bash
# 10-install-dependencies.sh — installe/met à jour rclone (>= RCLONE_MIN_VERSION) et fuse3.
# Idempotent : ne réinstalle rien si déjà à jour.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
source ./lib.sh

RCLONE_INSTALL_DIR="$HOME/.local/bin"

# EXCEPTION TEMPORAIRE (2026-08-25) : la dernière stable v1.75.0 (31/07/2026)
# rejette l'authentification protondrive avec l'erreur Proton "This version
# of the app is no longer supported" (Code=2028) — cf. issue rclone #9764,
# fermée le 12/08/2026, donc APRÈS la coupe de v1.75.0 : le correctif n'est
# pas encore dans une release stable. On installe le canal beta (rebuild à
# chaque commit sur master) le temps qu'une nouvelle stable sorte. À
# repasser sur RCLONE_CHANNEL=stable dès qu'une stable > 1.75.0 est
# disponible (vérifier: rclone version, puis relancer ce script).
RCLONE_CHANNEL="${RCLONE_CHANNEL:-beta}"

install_rclone() {
    if command -v rclone &>/dev/null; then
        local current
        current="$(rclone_version)"
        if [ -n "$current" ] && version_ge "$current" "$RCLONE_MIN_VERSION" && [ "$RCLONE_CHANNEL" = "stable" ]; then
            log "rclone $current déjà installé (>= $RCLONE_MIN_VERSION) — rien à faire"
            return 0
        fi
        log "rclone présent en version $current — (ré)installation canal '$RCLONE_CHANNEL'"
    else
        log "rclone absent — installation canal '$RCLONE_CHANNEL'"
    fi

    local url
    if [ "$RCLONE_CHANNEL" = "beta" ]; then
        url="https://beta.rclone.org/rclone-beta-latest-linux-amd64.zip"
    else
        url="https://downloads.rclone.org/rclone-current-linux-amd64.zip"
    fi

    # Binaire portable dans ~/.local/bin (pas de sudo/dpkg requis — évite
    # toute dépendance à un mot de passe root, non disponible dans ce
    # contexte d'exécution non-interactif).
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    curl -fsSL -o "$tmp/rclone.zip" "$url"
    unzip -q "$tmp/rclone.zip" -d "$tmp"
    mkdir -p "$RCLONE_INSTALL_DIR"
    install -m 755 "$tmp"/rclone-*-linux-amd64/rclone "$RCLONE_INSTALL_DIR/rclone"

    local installed
    installed="$("$RCLONE_INSTALL_DIR/rclone" version 2>/dev/null | head -1)"
    command -v rclone &>/dev/null || die "$RCLONE_INSTALL_DIR n'est pas dans le PATH — ajoute-le à ton shell rc"
    log "rclone installé avec succès dans $RCLONE_INSTALL_DIR: $installed"
}

install_fuse() {
    if command -v fusermount3 &>/dev/null; then
        log "fuse3 déjà installé ($(fusermount3 --version 2>&1 | head -1))"
        return 0
    fi
    log "fuse3 absent — installation"
    sudo apt-get update -qq
    sudo apt-get install -y fuse3
    command -v fusermount3 &>/dev/null || die "installation de fuse3 échouée"
    log "fuse3 installé ($(fusermount3 --version 2>&1 | head -1))"
}

install_rclone
install_fuse
