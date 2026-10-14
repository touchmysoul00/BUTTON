#!/usr/bin/env bash
# Starts Rojo and pulls Claude's changes from GitHub every 5 seconds.
# Run from the button folder: ./dev.sh   (Ctrl+C stops both)
cd "$(dirname "$0")"
while true; do git pull -q 2>/dev/null; sleep 5; done &
PULL_PID=$!
trap 'kill $PULL_PID 2>/dev/null' EXIT
./rojo.exe serve
