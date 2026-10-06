[Unit]
Description=External Media Disk
BindsTo=__DEVICE_UNIT__
After=__DEVICE_UNIT__

[Mount]
What=/dev/disk/by-uuid/__MEDIA_UUID__
Where=/data/media
Type=ext4
Options=defaults,x-systemd.device-timeout=60

[Install]
WantedBy=multi-user.target
