#!/bin/bash

set -euo pipefail

SCRIPT="./portagit-snapshot"
NOW="2026-05-23 00:00:00"

run_case() {
    local name input expected actual

    name=$1
    input=$2
    expected=$3
    actual=$(printf '%s\n' "$input" | "$SCRIPT" --plan-retention --now "$NOW")

    if [ "$actual" = "$expected" ]; then
        printf 'PASS %s\n' "$name"
    else
        printf 'FAIL %s\n' "$name"
        printf 'expected:\n%s\n' "$expected"
        printf 'actual:\n%s\n' "$actual"
        exit 1
    fi
}

run_case "recent snapshots are kept" \
"/snapshots/snapshot-2026-05-22_000000
/snapshots/snapshot-2026-05-10_000000
/snapshots/snapshot-2026-04-24_000000" \
""

run_case "single archive snapshot is kept" \
"/snapshots/snapshot-2026-04-01_000000" \
""

run_case "old snapshots are deleted" \
"/snapshots/snapshot-2025-10-01_000000
/snapshots/snapshot-2024-01-01_000000" \
"/snapshots/snapshot-2025-10-01_000000
/snapshots/snapshot-2024-01-01_000000"

run_case "archive newest is deleted when interval is under thirty days" \
"/snapshots/snapshot-2026-04-20_000000
/snapshots/snapshot-2026-04-01_000000" \
"/snapshots/snapshot-2026-04-20_000000"

run_case "archive snapshots are kept when interval equals thirty days" \
"/snapshots/snapshot-2026-04-20_000000
/snapshots/snapshot-2026-03-21_000000" \
""

run_case "mixed retention rules" \
"/snapshots/snapshot-2026-05-20_000000
/snapshots/snapshot-2026-04-20_000000
/snapshots/snapshot-2026-04-10_000000
/snapshots/snapshot-2026-03-01_000000
/snapshots/snapshot-2025-10-01_000000" \
"/snapshots/snapshot-2025-10-01_000000
/snapshots/snapshot-2026-04-20_000000"

run_case "home source snapshot path" \
"/home/snapshots/snapshot-2026-04-20_000000
/home/snapshots/snapshot-2026-04-01_000000" \
"/home/snapshots/snapshot-2026-04-20_000000"
