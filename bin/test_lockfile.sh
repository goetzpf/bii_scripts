#!/bin/sh

. lockfile.sh

with_lock lock 10
sleep 3
echo done
