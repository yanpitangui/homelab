#!/usr/bin/env bash
# Restic backup of homelab state. Run by backup.timer (see systemd/).
# Config comes from /etc/homelab/backup.env (rendered from backup/backup.env.tpl):
#   RESTIC_REPOSITORY, RESTIC_PASSWORD, DB_PASSWORD
set -euo pipefail

source /etc/homelab/backup.env

# Optional Healthchecks.io monitoring: HC_PING_URL in backup.env. Pings /start, then the exit code
# (/0 = success), and Healthchecks alerts on failure or when the ping is missing.
HC_PING_URL="${HC_PING_URL//[[:space:]]/}"
hc_ping() { [[ -n "${HC_PING_URL:-}" ]] && curl -fsS -m 10 --retry 3 -o /dev/null "${HC_PING_URL}$1" 2>/dev/null || true; }
trap 'hc_ping "/$?"' EXIT
hc_ping /start

# Runs as a normal user. restic needs cap_dac_read_search to read files owned by other uids
# (one-time: sudo setcap cap_dac_read_search=+ep /usr/bin/restic). apt upgrades reset it.
if ! getcap "$(command -v restic)" | grep -q cap_dac_read_search; then
  echo "ERROR: restic lacks cap_dac_read_search; run: sudo setcap cap_dac_read_search=+ep $(command -v restic)" >&2
  exit 1
fi
export RCLONE_CONFIG RESTIC_REPOSITORY RESTIC_PASSWORD

HERE="$(cd "$(dirname "$0")" && pwd)"
DUMP_DIR=/srv/appdata/db-dumps
mkdir -p "$DUMP_DIR"

# Consistent Immich DB dump. The live db/ folder is NOT backed up: a file copy
# of a running Postgres can be corrupt.
docker exec -e PGPASSWORD="$DB_PASSWORD" immich_postgres \
  pg_dump -U postgres -Fc immich > "$DUMP_DIR/immich.dump.tmp"
mv "$DUMP_DIR/immich.dump.tmp" "$DUMP_DIR/immich.dump"

restic backup \
  /srv/appdata \
  /opt/homelab \
  /data/media/immich/library/backups \
  --exclude-file="$HERE/excludes.txt" \
  --exclude /srv/appdata/monitoring/prometheus

# Retention; prune weekly (Sunday) to keep the run short
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
  $([[ "$(date +%u)" == 7 ]] && echo --prune)

# Verify a slice of the repo on the 1st of the month
if [[ "$(date +%d)" == 01 ]]; then
  restic check --read-data-subset=5%
fi
