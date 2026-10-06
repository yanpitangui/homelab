#!/bin/sh

echo "[port-sync] started"

while true; do
  PORT=$(tr -dc '0-9' < /gluetun/forwarded_port 2>/dev/null)

  if [ -z "$PORT" ]; then
    echo "[port-sync] port not ready"
    sleep 5
    continue
  fi

  RESP=$(wget -qO- -T 5 http://127.0.0.1:8080/api/v2/app/preferences 2>/dev/null)

  if [ -z "$RESP" ]; then
    echo "[port-sync] qbittorrent unavailable"
    sleep 15
    continue
  fi

  CURRENT=$(echo "$RESP" | sed -n 's/.*"listen_port":[ ]*\([0-9]*\).*/\1/p')

  if [ -z "$CURRENT" ]; then
    echo "[port-sync] parse failed"
    sleep 15
    continue
  fi

  if [ "$CURRENT" != "$PORT" ]; then
    echo "[port-sync] updating port: $CURRENT -> $PORT"

    wget -qO- -T 5 \
      --post-data="json={\"listen_port\":$PORT}" \
      http://127.0.0.1:8080/api/v2/app/setPreferences \
      >/dev/null 2>&1
  else
    echo "[port-sync] port OK ($PORT)"
  fi

  sleep 15
done
