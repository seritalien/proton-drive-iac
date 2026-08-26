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
#     verrouillé via flock (fd 200) sur toute sa durée.
#   - Pas d'option de parallélisme interne documentée. Le gain de perf vient
#     de BATCHER tous les chemins d'un coup dans un seul appel (le CLI
#     accepte plusieurs chemins par commande) plutôt que d'enchaîner un
#     process par élément.
#   - Exclusion : voir SYNC_EXCLUDE_FILE dans lib.sh. Un chemin exclu (ou un
#     chemin dont un descendant est exclu) ne peut pas être transféré comme
#     un tout — on descend récursivement, ce qui coûte un appel CLI de plus
#     par niveau traversé. N'affecte que les branches qui contiennent une
#     exclusion, le reste de l'arbre garde le batching en un seul appel.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=../lib.sh
source ./lib.sh
set -e

LOCAL_ROOT="$HOME/ProtonDrive"
PROTON_CLOUD_ROOT="/my-files"
LOG="$XDG_STATE_HOME/proton-drive-cli-sync.log"
mkdir -p "$XDG_STATE_HOME" "$LOCAL_ROOT"
load_sync_excludes

# Verrou tenu pour toute la durée du script (pull + push).
mkdir -p "$(dirname "$PROTON_CLI_LOCK")"
exec 200>"$PROTON_CLI_LOCK"
if ! flock -n 200; then
    log "un autre run proton-drive est déjà en cours (verrou occupé) — cycle ignoré, pas une erreur"
    exit 0
fi

proton-drive filesystem list / &>/dev/null || die "non authentifié — lance cli/10-check-auth.sh"

sync_exit_code=0

# push_walk LOCAL_PATH REL CLOUD_PARENT
# Envoie LOCAL_PATH sous CLOUD_PARENT. Si REL (ou LOCAL_PATH lui-même) est
# exclu, ignore entièrement. Si un descendant de REL est exclu, ne peut pas
# batcher LOCAL_PATH tout entier : descend d'un niveau et répète pour
# chaque enfant.
push_walk() {
    local local_path="$1" rel="$2" cloud_parent="$3"

    if is_sync_excluded "$rel"; then
        echo "push: exclu — $rel"
        return 0
    fi

    if has_excluded_descendant "$rel"; then
        local child base
        shopt -s nullglob dotglob
        for child in "$local_path"/*; do
            base="$(basename "$child")"
            push_walk "$child" "$rel/$base" "$cloud_parent/$(basename "$local_path")"
        done
        shopt -u nullglob dotglob
        return 0
    fi

    if ! proton-drive filesystem upload -f skip -d merge "$local_path" "$cloud_parent"; then
        echo "AVERTISSEMENT: échec du push pour $local_path -> $cloud_parent"
        sync_exit_code=1
    fi
}

# pull_walk CLOUD_PATH REL LOCAL_PARENT
# Symétrique de push_walk, pour le rapatriement cloud -> local.
pull_walk() {
    local cloud_path="$1" rel="$2" local_parent="$3"

    if is_sync_excluded "$rel"; then
        echo "pull: exclu — $rel"
        return 0
    fi

    if has_excluded_descendant "$rel"; then
        local names name
        mapfile -t names < <(
            proton-drive filesystem list "$cloud_path" --json 2>/dev/null \
                | jq -r '.[] | select(.name.ok) | .name.value'
        )
        for name in "${names[@]}"; do
            pull_walk "$cloud_path/$name" "$rel/$name" "$local_parent/$(basename "$cloud_path")"
        done
        return 0
    fi

    if ! proton-drive filesystem download -f skip -d merge "$cloud_path" "$local_parent"; then
        echo "AVERTISSEMENT: échec du pull pour $cloud_path -> $local_parent"
        sync_exit_code=1
    fi
}

{
    echo "=== sync démarré $(date '+%Y-%m-%d %H:%M:%S') ==="
    if [ "${#SYNC_EXCLUDES[@]}" -gt 0 ]; then
        echo "exclusions actives: ${SYNC_EXCLUDES[*]}"
    fi

    echo "--- pull (cloud -> local) ---"
    mapfile -t cloud_names < <(
        proton-drive filesystem list "$PROTON_CLOUD_ROOT" --json 2>/dev/null \
            | jq -r '.[] | select(.name.ok) | .name.value'
    )
    if [ "${#cloud_names[@]}" -gt 0 ]; then
        clean_cloud_paths=()
        for name in "${cloud_names[@]}"; do
            if is_sync_excluded "$name"; then
                echo "pull: exclu — $name"
            elif has_excluded_descendant "$name"; then
                pull_walk "$PROTON_CLOUD_ROOT/$name" "$name" "$LOCAL_ROOT"
            else
                clean_cloud_paths+=("$PROTON_CLOUD_ROOT/$name")
            fi
        done
        if [ "${#clean_cloud_paths[@]}" -gt 0 ] \
            && ! proton-drive filesystem download -f skip -d merge "${clean_cloud_paths[@]}" "$LOCAL_ROOT"; then
            echo "AVERTISSEMENT: le pull batché a rencontré au moins une erreur (voir ci-dessus)"
            sync_exit_code=1
        fi
    else
        echo "rien côté cloud ($PROTON_CLOUD_ROOT vide ou JSON inattendu) — pull ignoré"
    fi

    echo "--- push (local -> cloud) ---"
    shopt -s nullglob dotglob
    local_entries=("$LOCAL_ROOT"/*)
    shopt -u nullglob dotglob
    if [ "${#local_entries[@]}" -gt 0 ]; then
        clean_local_paths=()
        for entry in "${local_entries[@]}"; do
            name="$(basename "$entry")"
            if is_sync_excluded "$name"; then
                echo "push: exclu — $name"
            elif has_excluded_descendant "$name"; then
                push_walk "$entry" "$name" "$PROTON_CLOUD_ROOT"
            else
                clean_local_paths+=("$entry")
            fi
        done
        if [ "${#clean_local_paths[@]}" -gt 0 ] \
            && ! proton-drive filesystem upload -f skip -d merge "${clean_local_paths[@]}" "$PROTON_CLOUD_ROOT"; then
            echo "AVERTISSEMENT: le push batché a rencontré au moins une erreur (voir ci-dessus)"
            sync_exit_code=1
        fi
    else
        echo "$LOCAL_ROOT vide — push ignoré"
    fi

    echo "=== sync terminé $(date '+%Y-%m-%d %H:%M:%S') (exit=$sync_exit_code) ==="
} >> "$LOG" 2>&1

if [ "$sync_exit_code" -ne 0 ]; then
    log "sync terminé AVEC ERREURS — voir $LOG"
    exit 1
fi
log "sync bidirectionnel (ajouts uniquement, pas de merge de contenu modifié) terminé — voir $LOG"
