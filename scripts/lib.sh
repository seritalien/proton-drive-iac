#!/usr/bin/env bash
# lib.sh — helpers partagés par tous les scripts de proton-drive-iac
# shellcheck shell=bash
# shellcheck disable=SC2034 # variables consommées par les scripts qui sourcent ce fichier, pas ici

set -euo pipefail

RCLONE_MIN_VERSION="1.75.0"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
SYSTEMD_USER_DIR="$XDG_CONFIG_HOME/systemd/user"
PROTON_MOUNT="$HOME/ProtonDrive"
RCLONE_REMOTE="protondrive"
# Pas de TPM sur cette machine et aucun TTY disponible dans cet
# environnement d'exécution pour saisir un mot de passe sudo : le
# host-key systemd-creds (--with-key=host) nécessite root pour
# `systemd-creds setup` ET pour le déchiffrement (unit système, pas
# --user). Repli documenté : fichier chmod 600, protégé par les
# permissions Unix standard — cohérent avec un service --user, sans
# sudo. Voir README.md "Sécurité du secret" pour le chemin de montée
# en robustesse si une machine avec TPM est disponible un jour.
CONFIG_PASS_FILE="$XDG_CONFIG_HOME/proton-drive/rclone-config-pass"

# Liste optionnelle de chemins (relatifs à ~/ProtonDrive) à exclure du sync
# CLI, un par ligne, lignes vides et commençant par # ignorées. Fichier
# personnel — jamais dans ce dépôt (voir .gitignore).
SYNC_EXCLUDE_FILE="$XDG_CONFIG_HOME/proton-drive/sync-exclude"

# Charge SYNC_EXCLUDE_FILE dans le tableau global SYNC_EXCLUDES.
load_sync_excludes() {
    SYNC_EXCLUDES=()
    [ -f "$SYNC_EXCLUDE_FILE" ] || return 0
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        case "$line" in \#*) continue ;; esac
        SYNC_EXCLUDES+=("$line")
    done < "$SYNC_EXCLUDE_FILE"
}

# $1 = chemin relatif à tester. Vrai si exactement exclu.
is_sync_excluded() {
    local rel="$1" ex
    for ex in "${SYNC_EXCLUDES[@]}"; do
        [ "$rel" = "$ex" ] && return 0
    done
    return 1
}

# $1 = chemin relatif à tester. Vrai si un de ses descendants est exclu
# (donc ce chemin ne peut pas être transféré comme un tout — il faut
# descendre récursivement dedans).
has_excluded_descendant() {
    local rel="$1" ex
    for ex in "${SYNC_EXCLUDES[@]}"; do
        case "$ex" in
            "$rel"/*) return 0 ;;
        esac
    done
    return 1
}

# Le CLI officiel proton-drive garde un cache SQLite local partagé entre
# TOUTES ses invocations (~/.local/share/proton-drive-cli). Deux
# invocations concurrentes → "SQLiteError: database is locked" (vérifié en
# pratique, non documenté officiellement — le CLI ne supporte PAS l'exécution
# parallèle). PROTON_CLI_LOCK sert de mutex : tout appel à `proton-drive`
# dans ce repo doit passer par proton_drive_locked() ci-dessous.
PROTON_CLI_LOCK="$XDG_STATE_HOME/proton-drive-cli.lock"
export PROTON_DRIVE_LOG_LEVEL="${PROTON_DRIVE_LOG_LEVEL:-WARNING}"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { log "ERREUR: $*" >&2; exit 1; }

require_cmd() {
    command -v "$1" &>/dev/null || die "commande requise introuvable: $1"
}

# Exécute `proton-drive "$@"` sous verrou exclusif (non-bloquant : si une
# autre invocation tient déjà le verrou, échoue immédiatement plutôt que de
# s'empiler derrière un run qui pourrait durer des heures sur un gros dossier).
proton_drive_locked() {
    mkdir -p "$(dirname "$PROTON_CLI_LOCK")"
    flock -n "$PROTON_CLI_LOCK" -c "proton-drive $(printf '%q ' "$@")"
}

# Compare deux versions "X.Y.Z" — retourne 0 (vrai) si $1 >= $2
version_ge() {
    [ "$1" = "$2" ] && return 0
    local higher
    higher="$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)"
    [ "$higher" = "$1" ]
}

rclone_version() {
    rclone version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}
