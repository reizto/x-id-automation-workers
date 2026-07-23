#!/bin/bash
# x_throttle.sh — shared cross-cron throttle for X ${X_PRIMARY_HANDLE:-@your_primary_account} posts
# Usage: source this BEFORE running the actual script.
#   source "$(dirname "$0")/x_throttle.sh" "job_name"
#
# How it works:
#   - Reads /tmp/x_last_post_epoch — last time ANY X cron posted
#   - If < MIN_GAP seconds ago, sleep the remainder (jittered 0-120s)
#   - After posting, caller does: x_throttle_done
#
# This prevents 2+ X crons from posting within minutes of each other,
# which triggers X's non-prem rate limit (~5-6 posts/hour).

# Per-account throttle: ${X_HANDLE:-@your_id_account} (X_TARGET_MODE=id) and ${X_PRIMARY_HANDLE:-@your_primary_account} (unset)
# get their OWN epoch file so they don't throttle each other.
X_THROTTLE_ACCOUNT="${X_TARGET_MODE:-primary_account}"
THROTTLE_FILE="/tmp/x_last_post_epoch_${X_THROTTLE_ACCOUNT}"
MIN_GAP=${X_THROTTLE_MIN_GAP:-900}  # 15 minutes default

x_throttle_wait() {
    local JOB_NAME="${1:-unknown}"
    local NOW=$(date +%s)
    local LAST=0
    [ -f "$THROTTLE_FILE" ] && LAST=$(cat "$THROTTLE_FILE" 2>/dev/null)
    LAST=${LAST:-0}

    local ELAPSED=$(( NOW - LAST ))
    if [ "$ELAPSED" -lt "$MIN_GAP" ]; then
        local REMAIN=$(( MIN_GAP - ELAPSED ))
        # Add jitter 0-120s so crons don't wake up at the exact same second
        local JITTER=$(( RANDOM % 121 ))
        local WAIT=$(( REMAIN + JITTER ))
        echo "[$(date)] ⏳ $JOB_NAME: throttle wait ${WAIT}s (last post ${ELAPSED}s ago, min gap ${MIN_GAP}s)" >> /tmp/x_throttle.log
        sleep "$WAIT"
    fi
}

x_throttle_done() {
    date +%s > "$THROTTLE_FILE"
}
