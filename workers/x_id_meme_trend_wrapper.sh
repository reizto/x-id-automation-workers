#!/usr/bin/env bash
# Wrapper: ID Meme Trend Rewriter for ${X_HANDLE:-@your_id_account}
# - flock (no overlap), jitter (anti-bot), throttle floor
# - silent unless actually posted or failed
set -uo pipefail
export TZ=Asia/Jakarta

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LOG="/tmp/x_id_meme_$(date +%Y%m%d_%H%M%S).log"
LOCK="/tmp/x_id_meme.lock"
export X_TARGET_MODE=id

# --- WIB hour gate: prime time only 19:00-23:59 ---
HOUR=$(date +%H)
if [ "$HOUR" -lt 19 ] || [ "$HOUR" -ge 24 ]; then
  exit 0
fi

# --- throttle floor: min gap between posts (default 45 min) ---
# Cron is 4x/night; 45m prevents accidental duplicates while allowing 3-5/day.
export X_THROTTLE_MIN_GAP="${X_THROTTLE_MIN_GAP:-2700}"

exec 9>"$LOCK"
if ! flock -n 9; then
  # previous run still going — skip silently
  exit 0
fi

# --- jitter 0-360s so post time drifts off the cron-minute grid ---
sleep $(( RANDOM % 360 ))

cd "$SCRIPT_DIR" || exit 1

# --- throttle check (per-account, reuse x_throttle.sh gap logic inline) ---
THROTTLE_FILE="/tmp/x_last_post_epoch_id_account_meme"
NOW=$(date +%s)
if [ -f "$THROTTLE_FILE" ]; then
  LAST=$(cat "$THROTTLE_FILE" 2>/dev/null || echo 0)
  GAP=$(( NOW - LAST ))
  if [ "$GAP" -lt "$X_THROTTLE_MIN_GAP" ]; then
    exit 0  # too soon, skip silently
  fi
fi

timeout 300 ${PYTHON:-python3} "${APP_DIR:-$SCRIPT_DIR/../core}/x_id_meme_trend.py" --post > "$LOG" 2>&1
RC=$?

# --- report only on real post or failure ---
if grep -q "^POSTED" "$LOG"; then
  echo "$NOW" > "$THROTTLE_FILE"
  URL=$(grep -A1 "^POSTED" "$LOG" | tail -1)
  CAP=$(grep "^Caption:" "$LOG" | head -1)
  echo "🖼️ Meme ${X_HANDLE:-@your_id_account} posted"
  echo "$URL"
  echo "$CAP"
elif grep -q "POST FAILED" "$LOG"; then
  echo "⚠️ Meme ${X_HANDLE:-@your_id_account} post FAILED"
  tail -5 "$LOG"
elif [ $RC -ne 0 ]; then
  echo "⚠️ Meme trend script error (rc=$RC)"
  tail -5 "$LOG"
fi
# else: silent (skipped/no-op)

# cleanup old logs (keep 3 days)
find /tmp -maxdepth 1 -name 'x_id_meme_*.log' -mtime +3 -delete 2>/dev/null || true
exit 0
