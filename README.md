# homelab

Docker Compose stacks for a single Debian server, deployed with [Komodo](https://komo.do).
Every secret and address lives in 1Password (vault `Homelab`). The `.env.tpl` files hold
`{{ op://... }}` references that are rendered into `.env` files at deploy time.

## Layout

| Dir | What | State on the server |
|---|---|---|
| `plex/` | Plex, Sonarr, Radarr, Bazarr, Prowlarr, qBittorrent behind Gluetun (ProtonVPN), Seerr, Maintainerr | `/srv/appdata/<service>`, media in `/data/media` |
| `immich/` | Immich + Postgres + Valkey | `/data/media/immich/{library,db}` |
| `proxy/` | Nginx Proxy Manager | `/srv/appdata/proxy` |
| `dns/` | Technitium DNS | `/srv/appdata/dns` |
| `monitoring/` | Prometheus, Grafana, node-exporter, cAdvisor | `/srv/appdata/monitoring` |
| `komodo/` | Komodo Core + Periphery + FerretDB (UI on :9120) | `/srv/appdata/komodo` |
| `backup/` | restic script + systemd timer | |
| `scripts/` | `bootstrap.sh`, `render-env.sh` | |

## Where things live

| Path | Contents |
|---|---|
| `/srv/appdata/<service>` | config and state for every app (the backup root) |
| `/data/media/...` | media and downloads on the big disk; Immich library and db under `/data/media/immich` |
| `/opt/homelab` | this repo |
| `/etc/homelab` | host secrets: `op-token`, `backup.env` |

## Secrets

Vault `Homelab` holds one **Password** item per value (the value sits in the default `password` field):

| Item | Used for |
|---|---|
| `protonvpn-wireguard` | WireGuard private key (plex stack) |
| `plex-advertise-url` | Plex advertise URL |
| `allowed-networks` | Plex allowed networks (comma-separated CIDRs) |
| `lan-subnet` | LAN CIDR allowed through the VPN firewall |
| `server-ip` | host IP the DNS server binds to |
| `immich-db` | Immich Postgres password (immich stack and backup) |
| `grafana-admin` | Grafana admin password |
| `restic` | restic repo password |
| `healthchecks-backup` | Healthchecks.io ping URL for the backup job |
| `komodo-db` | Komodo Postgres password |
| `komodo-admin` | Komodo UI admin password (initial) |
| `komodo-webhook` | Komodo webhook secret (any long random string) |
| `komodo-jwt` | Komodo JWT signing secret (any long random string) |

The vault also has a document `rclone-conf`. Restore it with
`op document get rclone-conf --vault Homelab --out-file ~/.config/rclone/rclone.conf`.

- The server holds one bootstrap secret: a read-only 1Password service account token in
  `/etc/homelab/op-token`.
- `scripts/render-env.sh [stack...]` writes `<stack>/.env` (gitignored).
- 1Password is used when you deploy or redeploy. Running containers work on their own.

## Dependencies

Installed on the server (Debian 12+) by `scripts/bootstrap.sh`:

| Package | Used for |
|---|---|
| `docker-ce` + `docker-compose-plugin` | runs every stack |
| `1password-cli` (`op`) | renders `.env` files from `.env.tpl` |
| `restic` | backups |
| `rclone` | Google Drive transport for restic |
| `git`, `curl`, `gnupg`, `ca-certificates` | clone the repo, add apt repos |
| `libcap2-bin`, `acl` | rootless backup (restic capability) and file access under `/srv/appdata` |

Provided by you:

| Item | Where it goes |
|---|---|
| 1Password service account token | `/etc/homelab/op-token` |
| media disk mount | `/data/media` in `/etc/fstab` |

Docker pulls the container images (Komodo, Plex, and the rest).

## Rebuild from zero

1. Install Debian, create a user, add SSH keys.
2. `git clone <this repo> /opt/homelab && cd /opt/homelab && sudo scripts/bootstrap.sh`
3. Provide the items from the second table under Dependencies.
4. Restore state: `restic restore latest --target / --include /srv/appdata`
   (Immich database: see Backups).
5. Restore the rclone config (see Secrets), then run `scripts/render-env.sh`.
6. Start Komodo by hand, since it runs outside its own management:
   `scripts/render-env.sh komodo && cd komodo && docker compose up -d`.
   Then create the Sync `homelab` (Files on Host, `resources.toml`) and deploy the stacks, `dns` first.
7. Install the backup timer:
   ```
   op inject -i backup/backup.env.tpl -o /etc/homelab/backup.env
   mkdir -p ~/.config/systemd/user && cp backup/systemd/* ~/.config/systemd/user/
   systemctl --user daemon-reload && systemctl --user enable --now homelab-backup.timer
   ```
   Bootstrap sets `cap_dac_read_search` on restic and enables linger. After an `apt upgrade`
   of restic, re-run `sudo setcap cap_dac_read_search=+ep /usr/bin/restic`; the backup script
   reports it when needed.

## Plex claim token

Restoring `/srv/appdata` brings Plex back already claimed.
A fresh Plex without restored config takes a token from https://plex.tv/claim
(valid for about 4 minutes, so it is entered at start time) passed once:

```
cd plex && PLEX_CLAIM=claim-xxxxxxxx docker compose up -d plex
```

## Backups

`backup/backup.sh` runs twice a day as a user systemd timer. It dumps the Immich database
with `pg_dump`, then runs restic over `/srv/appdata`, `/opt/homelab` and Immich's own
database dumps (`library/backups`) into `gdrive:homelab-backups/homelab`.

| Covered | Handled differently |
|---|---|
| app config and state under `/srv/appdata` | the photo library is a copy of Google Photos, so it is re-imported when needed |
| Immich database via consistent dumps | the live Postgres `db/` folder is covered by those dumps |
| Komodo database via its dated dumps in `/srv/appdata/komodo/backups` | Komodo's live database volumes are covered by those dumps |

Monitoring: when `HC_PING_URL` is set in `backup.env` (1Password item `healthchecks-backup`), the script pings
[Healthchecks.io](https://healthchecks.io) at start and at the end with its exit code. Healthchecks alerts on a failed
run and on a missing ping, which covers a timer that did not fire.

Restore the Immich database from a dump: start the stack with an empty `db/`, then
`docker exec -i immich_postgres pg_restore -U postgres -d immich --clean --if-exists < /srv/appdata/db-dumps/immich.dump`
(check the Immich docs for the current procedure, and rehearse it once).

Monthly: restore into a scratch directory (`restic restore latest --target /tmp/r`) and compare.
