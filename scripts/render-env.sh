#!/usr/bin/env bash
# Render every <stack>/.env.tpl into <stack>/.env using 1Password.
# Needs: `op` CLI and OP_SERVICE_ACCOUNT_TOKEN (or /etc/homelab/op-token).
# Usage: scripts/render-env.sh [stack ...]   (default: all stacks)
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" && -r /etc/homelab/op-token ]]; then
  OP_SERVICE_ACCOUNT_TOKEN="$(cat /etc/homelab/op-token)"
  export OP_SERVICE_ACCOUNT_TOKEN
fi

stacks=("$@")
if [[ ${#stacks[@]} -eq 0 ]]; then
  mapfile -t stacks < <(find . -mindepth 2 -maxdepth 2 -name .env.tpl -printf '%h\n' | sed 's|^\./||' | grep -v '^backup$' | sort)
fi

for s in "${stacks[@]}"; do
  op inject --force -i "$s/.env.tpl" -o "$s/.env" >/dev/null
  chmod 600 "$s/.env"
  # Komodo/Periphery runs as root; hand the file back to the stack folder's owner
  chown --reference="$s" "$s/.env"
  echo "rendered $s/.env"
done
