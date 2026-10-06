#!/usr/bin/env bash
# Install host dependencies on a fresh Debian 12+ machine and create the directory layout.
# Run as root:  sudo scripts/bootstrap.sh
# Safe to re-run.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }

. /etc/os-release
USER_NAME="${SUDO_USER:-yanpitangui}"

apt-get update
apt-get install -y ca-certificates curl gnupg git restic rclone

# Docker Engine + compose plugin (official repo)
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$ID $VERSION_CODENAME stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
usermod -aG docker "$USER_NAME"

# 1Password CLI (official repo)
if ! command -v op >/dev/null; then
  curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
    | gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
    > /etc/apt/sources.list.d/1password.list
  apt-get update
  apt-get install -y 1password-cli
fi

# Backup runs as the normal user: let restic read all files, and keep user timers running without a login
apt-get install -y libcap2-bin
setcap cap_dac_read_search=+ep "$(command -v restic)"
loginctl enable-linger "$USER_NAME"

# Directory layout
install -d -m 0750 -o "$USER_NAME" -g "$USER_NAME" /etc/homelab
install -d -o "$USER_NAME" -g "$USER_NAME" /srv/appdata/{plex,sonarr,radarr,bazarr,prowlarr,qbittorrent,gluetun,seerr,maintainerr,dns,komodo/{backups,periphery},db-dumps,proxy/data,proxy/letsencrypt,monitoring/prometheus,monitoring/grafana}
install -d -o "$USER_NAME" -g "$USER_NAME" /opt/homelab
# install -d only chowns the last path component; fix parents
chown "$USER_NAME": /srv/appdata /srv/appdata/proxy /srv/appdata/monitoring

# Containers write files as other uids (npm, grafana, prometheus, ...); an ACL keeps them
# accessible to the normal user, now and for new files
apt-get install -y acl
setfacl -R -m "u:$USER_NAME:rwX" /srv/appdata
setfacl -R -d -m "u:$USER_NAME:rwX" /srv/appdata

echo
echo "Done. Still manual:"
echo "  1. mount the media disk at /data/media (fstab)"
echo "  2. put the 1Password service account token in /etc/homelab/op-token"
echo "  3. restore rclone.conf from the 1Password document rclone-conf (see README)"
echo "  4. log out/in so the docker group applies"
