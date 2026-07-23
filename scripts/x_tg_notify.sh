#!/bin/bash
# x_tg_notify.sh — optional Telegram notifier for detached X workers.
# Usage: source scripts/x_tg_notify.sh; x_tg_notify "message"
# Reads TELEGRAM_BOT_TOKEN from env (or ENV_FILE=.env) and sends to X_TG_CHAT / X_TG_THREAD.

if [ -n "${ENV_FILE:-}" ] && [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
elif [ -f ".env" ]; then
  # shellcheck disable=SC1091
  source ".env"
fi

X_TG_CHAT="${X_TG_CHAT:-}"
X_TG_THREAD="${X_TG_THREAD:-}"

x_tg_notify() {
    local TEXT="$1"
    [ -z "$TEXT" ] && return 0
    [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && { echo "[x_tg_notify] TELEGRAM_BOT_TOKEN unset" >&2; return 1; }
    [ -z "$X_TG_CHAT" ] && { echo "[x_tg_notify] X_TG_CHAT unset" >&2; return 1; }
    local MSG
    MSG=$(printf '```
%s
```' "$TEXT")
    if [ -n "$X_TG_THREAD" ]; then
      curl -s -m 15 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"         --data-urlencode "chat_id=${X_TG_CHAT}"         --data-urlencode "message_thread_id=${X_TG_THREAD}"         --data-urlencode "parse_mode=Markdown"         --data-urlencode "text=${MSG}" >/dev/null
    else
      curl -s -m 15 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"         --data-urlencode "chat_id=${X_TG_CHAT}"         --data-urlencode "parse_mode=Markdown"         --data-urlencode "text=${MSG}" >/dev/null
    fi
}
