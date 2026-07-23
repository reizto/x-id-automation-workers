#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-.}"
# Secret-like tokens
if grep -RInE '(ghp_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|xox[baprs]-|cf[a-z]{2}_[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{20,})' "$ROOT" --exclude-dir=.git; then
  echo 'credential gate failed: secret-like token found' >&2
  exit 1
fi
# Personal infra/path leaks
if grep -RInE '/home/ubuntu|ombro\.my\.id|ombro\.tech|mikigatari|JawiNeko|jawineko|sakuravoi|mhucex|-1003930761082|TELEGRAM_BOT_TOKEN=' "$ROOT" --exclude-dir=.git --exclude='.env.example' --exclude='credential_gate.sh'; then
  echo 'credential gate failed: personal identifier/path found' >&2
  exit 1
fi
echo 'credential gate OK'
