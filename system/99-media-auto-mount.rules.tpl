ACTION=="add", ENV{ID_FS_UUID}=="__MEDIA_UUID__", TAG+="systemd", ENV{SYSTEMD_WANTS}="data-media.mount"
