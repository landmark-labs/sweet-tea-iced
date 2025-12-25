#!/bin/bash
# Optimized R2 Sync Up Script
# Usage: sync-up

# Common R2 args (matching start_optimized.sh)
# --size-only: Ignore modification times (R2 modtimes are unreliable)
# --no-update-modtime: Don't waste time trying to update remote timestamps
RCLONE_ARGS="--fast-list --transfers ${RCLONE_TRANSFERS:-12} --checkers ${RCLONE_CHECKERS:-24} --size-only --no-update-modtime"

# Set LOCAL_ROOT to ComfyUI directory
: "${LOCAL_ROOT:=/opt/ComfyUI}"

# Check env
if [[ -z "${R2_BUCKET}" ]]; then
    echo "[r2] Error: R2_BUCKET not set."
    exit 1
fi

REMOTE="r2:${R2_BUCKET}${R2_PREFIX:+/${R2_PREFIX}}"
EXCLUDES=( "/**/.git/**" "/**/__pycache__/**" "/**/outputs/**" "/**/temp/**" "/**/*.tmp" "/**/*.part" )

# Directories to sync
PATHS=(custom_nodes user sweet_tea output scripts input models vlm)

echo "[r2] Starting optimized sync-up to ${REMOTE}..."
echo "[r2] Local Root: ${LOCAL_ROOT}"

for p in "${PATHS[@]}"; do
    src="${LOCAL_ROOT}/${p}"
    if [[ ! -d "$src" ]]; then
        echo "[r2] skip: ${src} (missing)"
        continue
    fi

    echo "[r2] sync: ${src} -> ${REMOTE}/${p}"
    
    # Run rclone
    rclone sync \
        "${src}" "${REMOTE}/${p}" \
        $RCLONE_ARGS \
        --copy-links \
        --delete-after \
        --stats 10s --stats-one-line --log-level NOTICE \
        $(for e in "${EXCLUDES[@]}"; do printf -- "--exclude %q " "$e"; done)

    rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "[r2] WARNING: sync for ${p} exited with ${rc}"
    fi
done

echo "[r2] Sync-up finished."
