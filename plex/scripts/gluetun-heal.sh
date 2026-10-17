#!/bin/sh

echo "[gluetun-heal] started"

LAST_START=""
DEPENDENTS="qbittorrent prowlarr port-sync"

# Dependents joined to a previous gluetun container (network_mode pins the container ID)
stale_dependents() {
  GLUETUN_ID=$(docker inspect -f '{{.Id}}' gluetun 2>/dev/null)
  STALE=""
  for C in $DEPENDENTS; do
    NET=$(docker inspect -f '{{.HostConfig.NetworkMode}}' "$C" 2>/dev/null) || continue
    [ "$NET" != "container:$GLUETUN_ID" ] && STALE="$STALE $C"
  done
  echo $STALE
}

while true; do
  START=$(docker inspect -f '{{.State.StartedAt}}' gluetun 2>/dev/null)

  if [ -z "$START" ]; then
    echo "[gluetun-heal] gluetun not found"
    sleep 30
    continue
  fi

  if [ -n "$(stale_dependents)" ]; then
    echo "[gluetun-heal] gluetun was recreated, waiting for stabilization..."
    # a full stack deploy may still be recreating the dependents itself
    sleep 20
    STALE=$(stale_dependents)
    if [ -n "$STALE" ] && [ "$(docker inspect -f '{{.State.Health.Status}}' gluetun)" = "healthy" ]; then
      echo "[gluetun-heal] recreating $STALE"
      docker compose up -d --no-deps --force-recreate $STALE
    fi
    LAST_START=""
  elif [ -z "$LAST_START" ]; then
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
