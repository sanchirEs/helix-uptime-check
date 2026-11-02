#!/usr/bin/env bash
# Checks Helix from outside its servers and tells Telegram when that changes.
# The result lives in state/status, which the workflow commits. See README.md.

set -uo pipefail
cd "$(dirname "$0")"
source ./lib.sh

: "${TELEGRAM_ALERT_BOT_TOKEN:?not set}"
: "${TELEGRAM_ALERT_CHAT_ID:?not set}"

ATTEMPTS="${ATTEMPTS:-3}"
ATTEMPT_WAIT_SECONDS="${ATTEMPT_WAIT_SECONDS:-20}"
KEEPALIVE_SECONDS=$((30 * 24 * 3600))

URLS=(
  "https://helix.mn/login"
  "https://helix.mn/api/health"
  "https://chat.helix.mn/"
  "https://matrix.helix.mn/_matrix/client/versions"
)

# Prints the HTTP code, or 000 if nothing answered. Any failure gets retried, so
# one blip can't alert. Certificate checks stay on: an expired one is an outage.
check_url() {
  local url="$1" code="000" attempt=1
  while [ "$attempt" -le "$ATTEMPTS" ]; do
    code="$(curl -sS -m 20 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)" || code="000"
    [ "$code" = "200" ] && break
    [ "$attempt" -lt "$ATTEMPTS" ] && sleep "$ATTEMPT_WAIT_SECONDS"
    attempt=$((attempt + 1))
  done
  echo "$code"
}

send_telegram() {
  curl -sS -f -m 20 -o /dev/null \
    "https://api.telegram.org/bot${TELEGRAM_ALERT_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_ALERT_CHAT_ID}" \
    --data-urlencode "text=$1" 2>/dev/null
}

failures=""
for url in "${URLS[@]}"; do
  code="$(check_url "$url")"
  echo "$code $url"
  if [ "$code" != "200" ]; then
    failures="${failures}${failures:+, }${url#https://} (${code})"
  fi
done

failing=0
[ -n "$failures" ] && failing=1

mkdir -p state
now="$(date +%s)"
prev="$(cat state/status 2>/dev/null || true)"
action="$(decide_action "$prev" "$failing" "$now")"
echo "state='$prev' action=$action"

# State only moves after the message is sent, so a failed send retries next run.
send_failed=0
case "$action" in
  alert_down) send_telegram "HELIX DOWN: $failures" && echo "down $now" > state/status || send_failed=1 ;;
  remind)     send_telegram "HELIX STILL DOWN: $failures" && echo "down $now" > state/status || send_failed=1 ;;
  alert_up)   send_telegram "HELIX RECOVERED" && echo "up" > state/status || send_failed=1 ;;
  none)       [ -f state/status ] || echo "up" > state/status ;;
esac

# GitHub turns off the schedule on a public repo after 60 days without activity.
# A small commit each month keeps it running.
last_keepalive="$(cat state/keepalive 2>/dev/null || echo 0)"
case "$last_keepalive" in ''|*[!0-9]*) last_keepalive=0 ;; esac
if [ $((now - last_keepalive)) -ge "$KEEPALIVE_SECONDS" ]; then
  echo "$now" > state/keepalive
fi

if [ "$send_failed" -eq 1 ]; then
  echo "Telegram send failed" >&2
  exit 2
fi
# A red run in the Actions tab means Helix was failing, or the alert couldn't go out.
[ "$failing" -eq 0 ]
