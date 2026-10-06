# Komodo

UI that deploys the stacks in this repo. Web UI on port 9120.

State in `/srv/appdata/komodo`:
- `backups/` dated database dumps from Core (included in the restic backup)
- `periphery/` clones of this repo and rendered `.env` files (re-created on deploy)
- Docker volumes `postgres-data`, `ferretdb-state` and `keys` hold the live database and the
  Core/Periphery keypair. The dated dumps in `backups/` cover the database, and Komodo
  regenerates keys.

1Password items (Password type, value in `password`): `komodo-db`, `komodo-admin`,
`komodo-webhook`, `komodo-jwt`.

## Stacks (files-on-server mode)

Stacks run from the checkout in `/opt/homelab`, mounted into Periphery at the same path.
They are defined in `resources.toml` (Core reads it as `/syncs/homelab/resources.toml`; the sync is named `homelab`).

One-time, in the UI: **Syncs → New** `homelab`, tick **Files on Host**,
resource path `resources.toml`. Then **Execute Sync**. Each stack's pre-deploy hook runs
`scripts/render-env.sh <stack>` to render its `.env` from 1Password.

Update flow: edit on your workstation, `rsync` to `/opt/homelab`, then Execute Sync / Redeploy.
To move to git later: point the Sync and stacks at the repo (repo, branch) and turn off files-on-host.

## Restore the Komodo database

Core writes dumps to `backups/`; see https://komo.do/docs/setup/backup to restore into a fresh install.
