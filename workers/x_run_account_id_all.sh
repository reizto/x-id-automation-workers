#!/usr/bin/env bash
set -Eeuo pipefail

# Manual foreground smoke runner for ${X_HANDLE:-@your_id_account} / ID account.
# Does NOT pause/disable cron schedules.
# Default: verifies cookie + runs foreground workers for trend/reply/quote/video.
# Mutualan is skipped by default to avoid duplicate original post spam; pass --with-mutualan to post one mutualan too.

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
APP_DIR="${APP_DIR:-$SCRIPT_DIR/../core}"
cd "$SCRIPT_DIR"
export TZ=Asia/Jakarta
export X_TARGET_MODE=id
export X_COOKIE_PERSISTENT="${X_COOKIE_PERSISTENT:-./cookies/x_cookies_id.json}"
export X_COOKIE_FILE="${X_COOKIE_FILE:-/tmp/x_cookies_id.json}"
export X_THROTTLE_MIN_GAP="0"
export PYTHONUNBUFFERED=1

WITH_MUTUALAN=0
if [[ "${1:-}" == "--with-mutualan" ]]; then
  WITH_MUTUALAN=1
fi

PY="${PYTHON:-python3}"

stamp(){ date '+%F %T %Z'; }
section(){ printf '\n========== %s | %s ==========' "$(stamp)" "$1"; printf '\n'; }

LOG="/tmp/x_account_id_manual_all_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

echo "🚀 Manual foreground smoke run for ${X_HANDLE:-@your_id_account} / ID"
echo "log=$LOG"
echo "target_mode=$X_TARGET_MODE cookie=$X_COOKIE_PERSISTENT"
echo "with_mutualan=$WITH_MUTUALAN"

show_newest(){
  local label="$1"; local pattern="$2"; local bg="$3"
  echo
  echo "--- ${label}: bg summary tail ---"
  if [[ -f "$bg" ]]; then tail -80 "$bg"; else echo "(no bg log: $bg)"; fi
  echo
  echo "--- ${label}: newest detailed log ---"
  local latest
  latest=$(ls -t $pattern 2>/dev/null | grep -v '_bg\.log$' | head -1 || true)
  if [[ -n "$latest" && -f "$latest" ]]; then
    echo "file=$latest"
    tail -160 "$latest"
  else
    echo "(no detailed log matching: $pattern, excluding *_bg.log)"
  fi
}

run_cmd(){
  local name="$1"; shift
  section "$name"
  set +e
  "$@"
  local rc=$?
  set -e
  echo "EXIT_CODE=$rc"
  return 0
}

run_worker(){
  local name="$1"; local script="$2"; local pattern="$3"; local bg="$4"
  section "$name"
  set +e
  bash "$script"
  local rc=$?
  set -e
  echo "EXIT_CODE=$rc"
  show_newest "$name" "$pattern" "$bg"
  return 0
}

run_cmd "Cookie Health Check" timeout 120 xvfb-run -a "$PY" -u "$APP_DIR/x_cookie_health_check_id.py"

if [[ "$WITH_MUTUALAN" == "1" ]]; then
  run_cmd "Mutualan Post" timeout 240 xvfb-run -a "$PY" -u "$APP_DIR/x_mutualan_post.py" --post
else
  section "Mutualan Post"
  echo "SKIPPED by default to avoid duplicate original post spam. Use --with-mutualan to force."
fi

# Foreground workers. These scripts internally write rich summaries + detailed logs;
# we print those files after each run so manual smoke has real evidence.
run_worker "Trend Rewriter" x_id_trend_rewriter_worker.sh "/tmp/x_id_trend_*.log" "/tmp/x_id_trend_bg.log"
run_worker "Reply Hunter" x_reply_hunter_id_worker.sh "/tmp/x_reply_hunter_id_*.log" "/tmp/x_reply_hunter_id_bg.log"
run_worker "Quote Hunter" x_quote_hunter_id_worker.sh "/tmp/x_quote_hunter_id_*.log" "/tmp/x_quote_hunter_id_bg.log"
run_worker "Video Repost" x_video_repost_id_worker.sh "/tmp/x_video_repost_id_*.log" "/tmp/x_video_repost_id_bg.log"

section "SUMMARY"
echo "Manual foreground run completed."
echo "log=$LOG"
