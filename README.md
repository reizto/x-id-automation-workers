# X ID Automation Workers

Curated worker-only release for an Indonesian-lane X automation account. This repo contains the **detached worker wrappers** and shared shell helpers only — no cookies, no API keys, no model names, and no private infrastructure paths.

> The core Python automation engine (`x_reply_hunter.py`, `x_quote_hunter.py`, `x_video_repost.py`, `x_id_trend_rewriter.py`, `x_id_meme_trend.py`) is expected in `APP_DIR` and is intentionally not bundled here.

## Included workers

| Worker | Purpose |
|---|---|
| `workers/x_reply_hunter_id_worker.sh` | Reply to selected ID/global Home/For You targets with same-language guard |
| `workers/x_quote_hunter_id_worker.sh` | Quote selected targets with Indonesia-lane settings |
| `workers/x_video_repost_id_worker.sh` | Repost selected videos with ID captioning path |
| `workers/x_id_trend_rewriter_worker.sh` | Trend → original tweet/image wrapper |
| `workers/x_id_meme_trend_wrapper.sh` | Prime-time meme/trend image poster wrapper |
| `workers/x_run_account_id_all.sh` | Manual smoke runner for the account lane |

## Quick setup

```bash
git clone https://github.com/reizto/x-id-automation-workers.git
cd x-id-automation-workers
cp .env.example .env
mkdir -p cookies
# put your exported X cookie jar at cookies/x_cookies_id.json
```

Edit `.env`:

```bash
X_HANDLE=@your_id_account
X_COOKIE_PERSISTENT=./cookies/x_cookies_id.json
APP_DIR=/path/to/your/x-core-scripts
PYTHON=/path/to/venv/bin/python3
```

Run one worker manually:

```bash
set -a; source .env; set +a
bash workers/x_reply_hunter_id_worker.sh
```

## Cron example

```cron
# Reply every ~12 min in the active window; worker adds jitter + throttle.
5,17,29,41,53 6-22 * * * cd /path/to/x-id-automation-workers && set -a && . ./.env && set +a && bash workers/x_reply_hunter_id_worker.sh
```

## Safety / secrets

- Real `.env`, `config.json`, and `cookies/` are gitignored.
- Telegram notifications are optional and read from env.
- Worker paths are config-driven (`APP_DIR`, `HELPER_DIR`, `PYTHON`).
- No production handles, model chains, router URLs, API keys, Telegram chat IDs, or cookie files are committed.

## Notes

These scripts automate a third-party UI. Keep rate limits conservative, use your own account/session, and comply with the platform rules that apply to your use case.
