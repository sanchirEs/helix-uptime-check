# helix-uptime-check

Checks Helix from GitHub's servers, so it still works when every Helix server is dead. It tells Telegram when something goes down, reminds you hourly while it stays down, and tells you when it recovers.

Every 5 minutes, each of these must answer 200:

- `https://helix.mn/login`
- `https://helix.mn/api/health` (app and database)
- `https://chat.helix.mn/`
- `https://matrix.helix.mn/_matrix/client/versions`

A failure is retried twice, 20 seconds apart, before it counts. An expired certificate counts as down.

## Setup

1. Push this to a new **public** GitHub repo. Public means unlimited free Actions minutes, and nothing here is secret.
2. In Settings → Secrets and variables → Actions, add `TELEGRAM_ALERT_BOT_TOKEN` and `TELEGRAM_ALERT_CHAT_ID`. Use a dedicated alert bot, not the Helix bot.
3. In the Actions tab, open "Check Helix" and press **Run workflow**. It should go green.

Run the tests with `bash test.sh`.

## How it remembers

A scheduled job has no memory, so `state/status` holds `up` or `down <time of last alert>`, committed by the workflow whenever it changes. `state/keepalive` gets a commit every 30 days, because GitHub disables schedules on a public repo after 60 days without activity.

## Limits

- GitHub runs schedules on a best-effort basis: runs can be late, and can be dropped under load. Expect to hear within about 10 minutes, not instantly. That's why UptimeRobot watches `/api/health` as well.
- If Telegram itself is unreachable, the run goes red and retries on the next one.
