#!/usr/bin/env bash

REMIND_EVERY_SECONDS=3600

# decide_action <previous state> <failing: 0|1> <now, epoch seconds>
# The previous state is "up" or "down <epoch of the last alert>". Anything else,
# like an empty or damaged state file, counts as up, so a failure still alerts.
decide_action() {
  local prev="$1" failing="$2" now="$3"
  local status="${prev%% *}" last_alert=""

  if [ "$status" = "down" ] && [ "$prev" != "down" ]; then
    last_alert="${prev#down }"
  fi
  case "$last_alert" in
    ''|*[!0-9]*) status="up" ;;
  esac

  if [ "$status" = "down" ]; then
    if [ "$failing" -eq 0 ]; then
      echo alert_up
    elif [ $((now - last_alert)) -ge "$REMIND_EVERY_SECONDS" ]; then
      echo remind
    else
      echo none
    fi
  elif [ "$failing" -eq 0 ]; then
    echo none
  else
    echo alert_down
  fi
}
