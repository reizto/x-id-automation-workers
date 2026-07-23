#!/bin/bash
# X Video Repost WORKER — ACCOUNT #2 (geo Indonesia). Runs detached.
# Dispatched by x_video_repost_id_wrapper.sh. Caption written in Indonesian.
# Separate cookie / lock / log / throttle namespace from ${X_PRIMARY_HANDLE:-@your_primary_account}.
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
export TZ="Asia/Jakarta"

# --- account #2 identity + targeting -------------------------------------
export X_TARGET_MODE="id"
export X_COOKIE_PERSISTENT="${X_COOKIE_PERSISTENT:-./cookies/x_cookies_id.json}"
export X_COOKIE_FILE="${X_COOKIE_FILE:-/tmp/x_cookies_id.json}"
cp -f "$X_COOKIE_PERSISTENT" "$X_COOKIE_FILE" 2>/dev/null

LOCK="/tmp/x_video_repost_id.lock"
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

source "${HELPER_DIR:-$SCRIPT_DIR/../scripts}/x_throttle.sh"
x_throttle_wait "VideoRepostID"

LOG_FILE="/tmp/x_video_repost_id_$(date +%Y%m%d_%H%M%S).log"
timeout --kill-after=10 300 xvfb-run -a ${PYTHON:-python3} "${APP_DIR:-$SCRIPT_DIR/../core}/x_video_repost.py" --auto >"$LOG_FILE" 2>&1
RESULT=$?

# Only mark the global X throttle when a post was actually submitted.
if grep -q '✅ Posted:\|✅ Post submitted' "$LOG_FILE"; then
  x_throttle_done
fi

source "${HELPER_DIR:-$SCRIPT_DIR/../scripts}/box_helper.sh"
source "${HELPER_DIR:-$SCRIPT_DIR/../scripts}/x_tg_notify.sh"
if grep -q 'No usable\|0 usable\|No video tweets\|skipping' "$LOG_FILE" && ! grep -q '🎯 Selected:' "$LOG_FILE"; then
  STATUS="⚠️ Nothing landed (no usable video)"
elif [ "$RESULT" -eq 124 ]; then
  STATUS="❌ Failed (timeout 300s)"
elif [ "$RESULT" -eq 0 ]; then
  STATUS="✅ Success"
elif [ "$RESULT" -eq 2 ]; then
  STATUS="⚠️ Nothing landed"
else
  STATUS="❌ Failed (exit $RESULT)"
fi
TS=$(date '+%Y-%m-%d %H:%M:%S')

CAPTION=$(grep -oP '✏️  Condensed: \K.*' "$LOG_FILE" | tail -1 || echo "")
SELECTED=$(grep -oP '🎯 Selected: \K.*' "$LOG_FILE" | tail -1 || echo "")
POST_URL=$(grep -oP '📤 Post.*: \K.*' "$LOG_FILE" | tail -1 || echo "")
VIEWS=$(grep -oP '🎯 Selected:.*\(views: \K[^)]+' "$LOG_FILE" | tail -1 || echo "")

BOX=$(box "🇮🇩 VIDEO REPOST (Akun Baru)" \
    "🕐 Time    : $TS" \
    "📊 Status  : $STATUS" \
    "👁️  Views   : ${VIEWS:-N/A}" \
    "✏️  Caption : ${CAPTION:-(none)}" \
    "📤 Post    : ${POST_URL:-N/A}")
[ -n "$SELECTED" ] && BOX="${BOX}
   🔗 Source  : $SELECTED"
echo "$BOX" >> /tmp/x_video_repost_id_bg.log
# Only notify on real post or hard failure (silent on 'nothing landed').
if echo "$STATUS" | grep -q '✅\|❌'; then
    x_tg_notify "$BOX" || true
fi

# Cleanup old logs
find /tmp -name "x_video_repost_id_*.log" -mtime +1 -delete 2>/dev/null || true

# Explicit exit: success / nothing-landed are not hard failures; timeouts/real failures stay nonzero.
if echo "$STATUS" | grep -q '✅\|⚠️'; then
    exit 0
fi
exit "$RESULT"
