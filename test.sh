#!/usr/bin/env bash
# Run with: bash test.sh
set -u
cd "$(dirname "$0")"
source ./lib.sh

fails=0
expect() {
  local want="$1" got
  shift
  got="$(decide_action "$@")"
  if [ "$got" = "$want" ]; then
    echo "ok   decide_action '$1' $2 $3 -> $got"
  else
    echo "FAIL decide_action '$1' $2 $3 -> $got (wanted $want)"
    fails=$((fails + 1))
  fi
}

expect none       "up"        0 2000
expect alert_down "up"        1 2000
expect none       "down 1000" 1 2000
expect none       "down 1000" 1 4599
expect remind     "down 1000" 1 4600
expect alert_up   "down 1000" 0 2000
expect alert_down ""          1 2000
expect alert_down "garbage"   1 2000
expect none       ""          0 2000

# An expired certificate has to count as down.
if grep -E 'curl.*( -[a-zA-Z]*k| --insecure)' check.sh; then
  echo "FAIL check.sh turns off certificate checks"
  fails=$((fails + 1))
else
  echo "ok   check.sh keeps certificate checks on"
fi

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
