#!/bin/bash
# Quote Hunter WORKER — ACCOUNT #2 (geo Indonesia, 80% ID / 20% global viral).
# Detached worker. Dispatched by x_quote_hunter_id_wrapper.sh.
# Separate cookie / lock / log / throttle namespace from ${X_PRIMARY_HANDLE:-@your_primary_account}.
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
export TZ="Asia/Jakarta"

# --- account #2 identity + targeting -------------------------------------
export X_TARGET_MODE="id"
# ${X_HANDLE:-@your_id_account}: target ORIGINAL tweets from Home with a balanced source split.
# 50% Following/Mengikuti + 50% For You; quote language mirrors the target tweet.
export X_ID_SOURCE="following"
export X_TARGET_SOURCE="following"
export X_HOME_TAB="following"
export X_ID_REQUIRE_LANG=""
export X_SAME_LANGUAGE_TARGET="1"
export X_FORYOU_PERCENT="50"
export X_FOLLOWING_NO_VIEW_GATE="1"
export X_TIMELINE_SCROLLS="8"
export X_FORYOU_SCROLLS="8"
export X_TIMELINE_COUNT="40"
export X_FORYOU_COUNT="40"
export X_SEARCH_ONLY="0"
export X_DISABLE_TIMELINE="0"
export X_DISABLE_FORYOU="0"
export X_MIN_VIEWS="20000"
export X_ID_MIN_VIEWS="20000"
export X_SEARCH_FILTER="top"
export X_SEARCH_RECENCY_DAYS="7"
export X_COOKIE_PERSISTENT="${X_COOKIE_PERSISTENT:-./cookies/x_cookies_id.json}"
export X_COOKIE_FILE="${X_COOKIE_FILE:-/tmp/x_cookies_id.json}"
cp -f "$X_COOKIE_PERSISTENT" "$X_COOKIE_FILE" 2>/dev/null

LOCK="/tmp/x_quote_hunter_id.lock"
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

# Anti-pattern jitter: small random 1-4 min offset so the real post time never lands
# exactly on cron minute, without delaying notifications too long.
JITTER=$(( 60 + RANDOM % 181 ))
echo "[$(date)] jitter sleep ${JITTER}s" >> /tmp/x_quote_hunter_id_bg.log
sleep "$JITTER"

# Separate throttle key so it doesn't gate on ${X_PRIMARY_HANDLE:-@your_primary_account}'s schedule.
source "${HELPER_DIR:-$SCRIPT_DIR/../scripts}/x_throttle.sh"
x_throttle_wait "QuoteHunterID"

LOG_FILE="/tmp/x_quote_hunter_id_$(date +%Y%m%d_%H%M%S).log"
export X_RUN_DEADLINE=165
timeout --kill-after=10 190 xvfb-run -a ${PYTHON:-python3} "${APP_DIR:-$SCRIPT_DIR/../core}/x_quote_hunter.py" >"$LOG_FILE" 2>&1
RESULT=$?

x_throttle_done

SUMMARY=$(grep -oP 'SUMMARY: \K.*' "$LOG_FILE" | tail -1)
QUOTES=$(echo "$SUMMARY" | grep -oP '"quotes":\s*\K[0-9]+' | tail -1)
REPLIES=$(echo "$SUMMARY" | grep -oP '"replies":\s*\K[0-9]+' | tail -1)
QUOTES=${QUOTES:-0}
REPLIES=${REPLIES:-0}
TS=$(date '+%Y-%m-%d %H:%M:%S')

source "${HELPER_DIR:-$SCRIPT_DIR/../scripts}/box_helper.sh"
source "${HELPER_DIR:-$SCRIPT_DIR/../scripts}/x_tg_notify.sh"
TOTAL=$(( QUOTES + REPLIES ))
if [ "$RESULT" -eq 0 ] && [ "$TOTAL" -gt 0 ]; then
    STATUS="✅ Posted"
elif [ "$TOTAL" -gt 0 ]; then
    STATUS="✅ Posted (exit $RESULT)"
else
    STATUS="⚠️ Nothing landed (exit $RESULT)"
fi

BOX=$(box "🇮🇩 QUOTE HUNTER (Akun Baru)" \
    "🕐 Time    : $TS" \
    "📊 Status  : $STATUS" \
    "🔁 Quotes  : $QUOTES" \
    "↩️  Replies : $REPLIES")
echo "$BOX" >> /tmp/x_quote_hunter_id_bg.log
# Only notify on real activity or hard failure.
if [ "$RESULT" -ne 0 ] || [ "$TOTAL" -gt 0 ]; then
    x_tg_notify "$BOX"
fi
