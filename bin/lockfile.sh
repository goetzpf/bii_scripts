#!/bin/sh

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

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
  local extra_cleanup="$3"
  cleanup() {
    rm -f "$lock"
    eval "$extra_cleanup"
  }
  set -e
  wait_for_lock "$lock" "$tmo"
  install_signal_handler 'cleanup' 0 INT TERM EXIT
}

# example

# with_lock lock 10
# sleep 3
# echo done
