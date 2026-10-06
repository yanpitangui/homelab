# sourced by bash, so values are quoted
RCLONE_CONFIG=/home/yanpitangui/.config/rclone/rclone.conf
RESTIC_REPOSITORY='rclone:gdrive:homelab-backups/homelab'
RESTIC_PASSWORD='{{ op://Homelab/restic/password }}'
DB_PASSWORD='{{ op://Homelab/immich-db/password }}'
HC_PING_URL='{{ op://Homelab/healthchecks-backup/password }}'
