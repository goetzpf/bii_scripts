#!/bin/sh

wait_for_lock() {
  local lock="$1"
  local timeout="$2"
  local counter=0
  until ln -s "$lock" "$lock" 2>/dev/null; do
    sleep 1
    counter=$(expr "$counter" + 1)
    if test "$counter" -ge $timeout; then
      echo "timeout waiting for lock file '$lock' to disappear"
      exit 1
    fi
  done
}

handle_signal() {
  eval $1 # cleanup
  local sig=$2
  shift
  if test $sig != EXIT; then
    trap - $sig EXIT
    kill -s $sig $$
  fi
}

install_signal_handler() {
  local cleanup="$1"
  shift
  for sig in $*; do
    trap "handle_signal $cleanup $sig" $sig
  done
}

with_lock() {
  lock="$1"
  local tmo="$2"
  cleanup() {
    rm -f "$lock"
  }
  set -e
  wait_for_lock "$lock" "$tmo"
  install_signal_handler 'cleanup' 0 INT TERM EXIT
}

# example

# with_lock lock 10
# sleep 3
# echo done
