#!/bin/bash
# Reply Hunter WORKER — ACCOUNT #2 (geo Indonesia, 80% ID / 20% global).
# Detached worker. Dispatched by x_reply_hunter_id_wrapper.sh.
# Separate cookie / lock / log / throttle namespace from ${X_PRIMARY_HANDLE:-@your_primary_account}.
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
export TZ="Asia/Jakarta"

# --- account #2 identity + targeting -------------------------------------
export X_TARGET_MODE="id"
# ${X_HANDLE:-@your_id_account}: target ORIGINAL tweets from Home with a balanced source split.
# 50% Following/Mengikuti + 50% For You; reply language mirrors the target tweet.
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
export X_FORYOU_ONLY="0"
export X_DISABLE_TIMELINE="0"
export X_DISABLE_FORYOU="0"
export X_MIN_VIEWS="20000"
export X_ID_MIN_VIEWS="20000"
export X_COOKIE_PERSISTENT="${X_COOKIE_PERSISTENT:-./cookies/x_cookies_id.json}"
export X_COOKIE_FILE="${X_COOKIE_FILE:-/tmp/x_cookies_id.json}"
# refresh /tmp copy from persistent each run (survives reboot / stays current)
cp -f "$X_COOKIE_PERSISTENT" "$X_COOKIE_FILE" 2>/dev/null

LOCK="/tmp/x_reply_hunter_id.lock"
# flock guard: skip if a previous worker is still running (jitter/throttle/post)
# → prevents double-reply + pileup when running 3x/hour.
exec 9>"$LOCK"
flock -n 9 || { echo "[$(date)] already running, skip" >> /tmp/x_reply_hunter_id_bg.log; exit 0; }

# Anti-bot: random human-like delay (0-5 min) BEFORE acting, so the actual
# post time drifts off the fixed cron-minute grid.
JITTER=$(( RANDOM % 301 ))
echo "[$(date)] jitter sleep ${JITTER}s" >> /tmp/x_reply_hunter_id_bg.log
sleep "$JITTER"

# Separate throttle key so it doesn't gate on ${X_PRIMARY_HANDLE:-@your_primary_account}'s schedule.
source "${HELPER_DIR:-$SCRIPT_DIR/../scripts}/x_throttle.sh"
x_throttle_wait "ReplyHunterID"

LOG_FILE="/tmp/x_reply_hunter_id_$(date +%Y%m%d_%H%M%S).log"
export X_RUN_DEADLINE=225
timeout --kill-after=15 240 xvfb-run -a ${PYTHON:-python3} "${APP_DIR:-$SCRIPT_DIR/../core}/x_reply_hunter.py" >"$LOG_FILE" 2>&1
RESULT=$?

x_throttle_done

QUOTES=$(grep -oP 'SUMMARY: \K.*' "$LOG_FILE" | grep -oP '"quotes":\s*\K[0-9]+' | tail -1 || echo "0")
REPLIES=$(grep -oP 'SUMMARY: \K.*' "$LOG_FILE" | grep -oP '"replies":\s*\K[0-9]+' | tail -1 || echo "0")
QUOTES=${QUOTES:-0}
REPLIES=${REPLIES:-0}
TS=$(date '+%Y-%m-%d %H:%M:%S')

source "${HELPER_DIR:-$SCRIPT_DIR/../scripts}/box_helper.sh"
source "${HELPER_DIR:-$SCRIPT_DIR/../scripts}/x_tg_notify.sh"
if [ "$RESULT" -eq 0 ]; then STATUS="✅ Success"; else STATUS="❌ Failed (exit $RESULT)"; fi

BOX=$(box "🇮🇩 REPLY HUNTER (Akun Baru)" \
    "🕐 Time    : $TS" \
    "📊 Status  : $STATUS" \
    "🔁 Quotes  : $QUOTES" \
    "↩️  Replies : $REPLIES")
if [ -s "$LOG_FILE" ]; then
    EXTRA=$(grep -E "🎯 Target|✅ Posted|🇮🇩 ID target|Skip below-target|ID target gate|ID pick highest" "$LOG_FILE" | head -10)
    [ -n "$EXTRA" ] && BOX="${BOX}
${EXTRA}"
fi
echo "$BOX" >> /tmp/x_reply_hunter_id_bg.log
# Only notify on real activity (quotes/replies > 0) or hard failure.
if [ "$RESULT" -ne 0 ] || [ "$REPLIES" != "0" ] || [ "$QUOTES" != "0" ]; then
    x_tg_notify "$BOX"
fi
