#!/usr/bin/env bash
# cli/20-sync-bidirectional.sh — sync pull+push via le CLI officiel
# (repli tant que le mount rclone est bloqué en amont).
#
# LIMITES HONNÊTES DU CLI OFFICIEL (vérifiées en pratique, pas juste la doc
# — cf. https://proton.me/support/drive-cli et
# https://github.com/ProtonDriveApps/sdk/blob/main/cli/README.md) :
#   - Pas de vrai moteur de sync (pas de diff/mtime) : upload/download avec
#     stratégie de conflit par nom. Un fichier MODIFIÉ des deux côtés (même
#     nom) n'est pas détecté — "skip"/"merge" laisse le premier arrivé.
#   - Cache SQLite local partagé entre TOUTES les invocations du CLI : deux
#     process concurrents → "SQLiteError: database is locked". Ce script ne
#     tourne donc JAMAIS en parallèle de lui-même ni d'un autre appel CLI —
#     verrouillé via proton_drive_locked() (flock non-bloquant).
#   - Pas d'option de parallélisme interne documentée. Le gain de perf vient
#     de BATCHER tous les chemins d'un coup dans un seul appel (le CLI
#     accepte plusieurs chemins par commande) plutôt que d'enchaîner un
#     process par élément — évite le coût de démarrage Bun + réouverture du
#     cache SQLite à chaque itération.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=../lib.sh
source ./lib.sh
set -e

LOCAL_ROOT="$HOME/ProtonDrive"
PROTON_CLOUD_ROOT="/my-files"
LOG="$XDG_STATE_HOME/proton-drive-cli-sync.log"
mkdir -p "$XDG_STATE_HOME" "$LOCAL_ROOT"

# Verrou tenu pour toute la durée du script (pull + push) : une seule
# invocation du CLI à la fois, jamais de flock imbriqué (proton_drive_locked
# n'est pas utilisé ICI — il servirait à se re-verrouiller lui-même).
mkdir -p "$(dirname "$PROTON_CLI_LOCK")"
exec 200>"$PROTON_CLI_LOCK"
if ! flock -n 200; then
    log "un autre run proton-drive est déjà en cours (verrou occupé) — cycle ignoré, pas une erreur"
    exit 0
fi

proton-drive filesystem list / &>/dev/null || die "non authentifié — lance cli/10-check-auth.sh"

exit_code=0
{
    echo "=== sync démarré $(date '+%Y-%m-%d %H:%M:%S') ==="

    echo "--- pull (cloud -> local) ---"
    mapfile -t cloud_names < <(
        proton-drive filesystem list "$PROTON_CLOUD_ROOT" --json 2>/dev/null \
            | jq -r '.[] | select(.name.ok) | .name.value'
    )
    if [ "${#cloud_names[@]}" -gt 0 ]; then
        cloud_paths=("${cloud_names[@]/#/$PROTON_CLOUD_ROOT/}")
        if ! proton-drive filesystem download -f skip -d merge "${cloud_paths[@]}" "$LOCAL_ROOT"; then
            echo "AVERTISSEMENT: le pull a rencontré au moins une erreur (voir ci-dessus)"
            exit_code=1
        fi
    else
        echo "rien côté cloud ($PROTON_CLOUD_ROOT vide ou JSON inattendu) — pull ignoré"
    fi

    echo "--- push (local -> cloud) ---"
    shopt -s nullglob dotglob
    local_entries=("$LOCAL_ROOT"/*)
    shopt -u nullglob dotglob
    if [ "${#local_entries[@]}" -gt 0 ]; then
        if ! proton-drive filesystem upload -f skip -d merge "${local_entries[@]}" "$PROTON_CLOUD_ROOT"; then
            echo "AVERTISSEMENT: le push a rencontré au moins une erreur (voir ci-dessus)"
            exit_code=1
        fi
    else
        echo "$LOCAL_ROOT vide — push ignoré"
    fi

    echo "=== sync terminé $(date '+%Y-%m-%d %H:%M:%S') (exit=$exit_code) ==="
} >> "$LOG" 2>&1

if [ "$exit_code" -ne 0 ]; then
    log "sync terminé AVEC ERREURS — voir $LOG"
    exit 1
fi
log "sync bidirectionnel (ajouts uniquement, pas de merge de contenu modifié) terminé — voir $LOG"
