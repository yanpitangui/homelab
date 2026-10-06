#!/bin/sh

echo "[gluetun-heal] started"

LAST_START=""
DEPENDENTS="qbittorrent prowlarr"

while true; do
  START=$(docker inspect -f '{{.State.StartedAt}}' gluetun 2>/dev/null)

  if [ -z "$START" ]; then
    echo "[gluetun-heal] gluetun not found"
    sleep 30
    continue
  fi

  if [ -z "$LAST_START" ]; then
    LAST_START="$START"
  elif [ "$START" != "$LAST_START" ]; then
    echo "[gluetun-heal] gluetun restart detected"
    LAST_START="$START"

    echo "[gluetun-heal] waiting for stabilization..."
    sleep 20

    for C in $DEPENDENTS; do
      echo "[gluetun-heal] restarting $C"
      docker restart "$C" >/dev/null 2>&1
      sleep 5
    done
  fi

  sleep 30
done
