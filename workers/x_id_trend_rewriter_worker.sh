#!/bin/bash
# ID Trend Rewriter WORKER — ACCOUNT #2 (${X_HANDLE:-@your_id_account}, geo Indonesia). Runs detached.
# Scrapes ID trends -> LLM rewrite (id) -> CF Flux image -> post as original tweet.
# Separate cookie / lock / log / throttle namespace from ${X_PRIMARY_HANDLE:-@your_primary_account}.
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
export TZ="Asia/Jakarta"

# --- account #2 identity + targeting -------------------------------------
export X_TARGET_MODE="id"
export X_COOKIE_PERSISTENT="${X_COOKIE_PERSISTENT:-./cookies/x_cookies_id.json}"
export X_COOKIE_FILE="${X_COOKIE_FILE:-/tmp/x_cookies_id.json}"
cp -f "$X_COOKIE_PERSISTENT" "$X_COOKIE_FILE" 2>/dev/null

LOCK="/tmp/x_id_trend.lock"
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

source "${HELPER_DIR:-$SCRIPT_DIR/../scripts}/x_throttle.sh"
x_throttle_wait "IDTrendRewriter"

LOG_FILE="/tmp/x_id_trend_$(date +%Y%m%d_%H%M%S).log"
timeout --kill-after=10 300 xvfb-run -a ${PYTHON:-python3} "${APP_DIR:-$SCRIPT_DIR/../core}/x_id_trend_rewriter.py" --post >"$LOG_FILE" 2>&1
RESULT=$?

if grep -q '✅ Posted:' "$LOG_FILE"; then
  x_throttle_done
fi

source "${HELPER_DIR:-$SCRIPT_DIR/../scripts}/box_helper.sh"
source "${HELPER_DIR:-$SCRIPT_DIR/../scripts}/x_tg_notify.sh"

POST_URL=$(grep -oP '✅ Posted: \K.*' "$LOG_FILE" | tail -1 || echo "")
TOPIC=$(grep -oP '🎯 chosen: \K.*' "$LOG_FILE" | tail -1 || echo "")
TWEET=$(grep -oP '✍️ tweet: \K.*' "$LOG_FILE" | tail -1 || echo "")
HASIMG=$(grep -q '🖼️ image saved' "$LOG_FILE" && echo "yes" || echo "no")
TS=$(date '+%Y-%m-%d %H:%M:%S')

if [ -n "$POST_URL" ]; then
  STATUS="✅ Posted"
elif [ "$RESULT" -eq 124 ]; then
  STATUS="❌ Failed (timeout 300s)"
elif [ "$RESULT" -eq 0 ]; then
  STATUS="⚠️ Ran but no post URL"
else
  STATUS="❌ Failed (exit $RESULT)"
fi

BOX=$(box "📈 TREND REWRITER (Akun Baru)" \
    "🕐 Time    : $TS" \
    "📊 Status  : $STATUS" \
    "🎯 Topik   : ${TOPIC:-(none)}" \
    "🖼️  Gambar  : $HASIMG" \
    "📝 Tweet   : ${TWEET:-(none)}" \
    "📤 Post    : ${POST_URL:-N/A}")
echo "$BOX" >> /tmp/x_id_trend_bg.log

if [ -n "$POST_URL" ] || echo "$STATUS" | grep -q '❌'; then
    x_tg_notify "$BOX" || true
fi

find /tmp -name "x_id_trend_*.log" -mtime +2 -delete 2>/dev/null || true

# Explicit exit: posted/no-post-warning are not hard failures; real script failures stay nonzero.
if [ -n "$POST_URL" ] || [ "$RESULT" -eq 0 ]; then
    exit 0
fi
exit "$RESULT"
