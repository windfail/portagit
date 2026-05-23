#!/bin/bash

set -euo pipefail

SOURCE="/"
SNAP_DIR=""
PREFIX="snapshot"
RECENT_DAYS=30
ARCHIVE_DAYS=180
MIN_ARCHIVE_INTERVAL_DAYS=30
DRY_RUN=0
PLAN_RETENTION_ONLY=0
NOW=""

usage() {
    printf 'Usage: %s [--source PATH] [--dry-run] [--plan-retention] [--now "YYYY-MM-DD HH:MM:SS"]\n' "$0"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --source)
            if [ "$#" -lt 2 ]; then
                usage >&2
                exit 1
            fi
            SOURCE=$2
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --plan-retention)
            PLAN_RETENTION_ONLY=1
            shift
            ;;
        --now)
            if [ "$#" -lt 2 ]; then
                usage >&2
                exit 1
            fi
            NOW=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
done

SOURCE=${SOURCE%/}
if [ -z "$SOURCE" ]; then
    SOURCE="/"
fi

if [ "$SOURCE" = "/" ]; then
    SNAP_DIR="/snapshots"
else
    SNAP_DIR="${SOURCE}/snapshots"
fi

now_epoch() {
    if [ -n "$NOW" ]; then
        date -d "$NOW" +%s
    else
        date +%s
    fi
}

snapshot_epoch() {
    local snap_name snap_date

    snap_name=$(basename "$1")
    snap_date=${snap_name#${PREFIX}-}
    date -d "${snap_date:0:10} ${snap_date:11:2}:${snap_date:13:2}:${snap_date:15:2}" +%s 2>/dev/null
}

list_snapshots() {
    if [ ! -d "$SNAP_DIR" ]; then
        return 0
    fi

    find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name "${PREFIX}-*" | sort -r
}

plan_retention_deletions() {
    local now recent_seconds archive_seconds min_archive_interval_seconds
    local snap snap_name snap_time age newest_time newest_snap second_time interval
    local -a archive_snapshots=()

    now=$(now_epoch)
    recent_seconds=$(( RECENT_DAYS * 86400 ))
    archive_seconds=$(( ARCHIVE_DAYS * 86400 ))
    min_archive_interval_seconds=$(( MIN_ARCHIVE_INTERVAL_DAYS * 86400 ))

    while read -r snap; do
        [ -n "$snap" ] || continue
        snap_name=$(basename "$snap")
        snap_time=$(snapshot_epoch "$snap" || true)

        if [ -z "$snap_time" ]; then
            printf 'Skipping snapshot with invalid timestamp: %s\n' "$snap_name" >&2
            continue
        fi

        age=$(( now - snap_time ))

        if [ "$age" -gt "$archive_seconds" ]; then
            printf '%s\n' "$snap"
        elif [ "$age" -ge "$recent_seconds" ]; then
            archive_snapshots+=("$snap_time"$'\t'"$snap")
        fi
    done

    if [ "${#archive_snapshots[@]}" -lt 2 ]; then
        return 0
    fi

    mapfile -t archive_snapshots < <(printf '%s\n' "${archive_snapshots[@]}" | sort -rn)

    while [ "${#archive_snapshots[@]}" -ge 2 ]; do
        newest_time=${archive_snapshots[0]%%$'\t'*}
        newest_snap=${archive_snapshots[0]#*$'\t'}
        second_time=${archive_snapshots[1]%%$'\t'*}
        interval=$(( newest_time - second_time ))

        if [ "$interval" -ge "$min_archive_interval_seconds" ]; then
            break
        fi

        printf '%s\n' "$newest_snap"
        archive_snapshots=("${archive_snapshots[@]:1}")
    done
}

create_snapshot() {
    local snap_name snap_path

    snap_name="${PREFIX}-$(date +%Y-%m-%d_%H%M%S)"
    snap_path="${SNAP_DIR}/${snap_name}"

    if [ "$DRY_RUN" -eq 1 ]; then
        printf 'Would create snapshot: %s -> %s\n' "$SOURCE" "$snap_path"
        return 0
    fi

    mkdir -p "$SNAP_DIR"

    if btrfs subvolume snapshot -r "$SOURCE" "$snap_path"; then
        printf 'Created snapshot: %s\n' "$snap_name"
    else
        printf 'Failed to create snapshot: %s\n' "$snap_name" >&2
        exit 1
    fi
}

delete_snapshots() {
    local snap

    while read -r snap; do
        [ -n "$snap" ] || continue

        if [ "$DRY_RUN" -eq 1 ]; then
            printf 'Would delete snapshot: %s\n' "$(basename "$snap")"
        else
            printf 'Deleting snapshot: %s\n' "$(basename "$snap")"
            btrfs subvolume delete "$snap"
        fi
    done
}

print_current_snapshots() {
    printf 'Current snapshots:\n'
    list_snapshots | sort | while read -r snap; do
        printf '  %s\n' "$(basename "$snap")"
    done
}

if [ "$PLAN_RETENTION_ONLY" -eq 1 ]; then
    plan_retention_deletions
    exit 0
fi

create_snapshot
list_snapshots | plan_retention_deletions | delete_snapshots
print_current_snapshots
