#!/bin/sh -e
if test \( -z "$1" \) -o \( "$1" = "-h" \); then
  echo "Add an email to the list of recipients for a monitored darcs repo."
  echo "Usage: darcs-monitor-add-email.sh EMAIL [DARCS-REPO]"
  exit 1
fi
email="$1"
repo="$2"
if test -z "$repo"; then
  repo="."
fi
cd $repo
echo $email >> _darcs/third-party/darcs-monitor/recipients
/opt/csr/bin/darcs-monitor.sh -n
