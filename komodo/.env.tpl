COMPOSE_KOMODO_IMAGE_TAG=2.3
TZ=America/Sao_Paulo

KOMODO_DATABASE_USERNAME=komodo
KOMODO_DATABASE_PASSWORD={{ op://Homelab/komodo-db/password }}

KOMODO_TITLE=Komodo
KOMODO_LOCAL_AUTH=true
KOMODO_INIT_ADMIN_USERNAME=admin
KOMODO_INIT_ADMIN_PASSWORD={{ op://Homelab/komodo-admin/password }}
KOMODO_DISABLE_USER_REGISTRATION=true
KOMODO_FIRST_SERVER_NAME=mini-pc
KOMODO_WEBHOOK_SECRET={{ op://Homelab/komodo-webhook/password }}
KOMODO_JWT_SECRET={{ op://Homelab/komodo-jwt/password }}
KOMODO_JWT_TTL=1-wk

KOMODO_PERIPHERY_PUBLIC_KEY=file:/config/keys/periphery.pub
PERIPHERY_CORE_ADDRESS=ws://core:9120
PERIPHERY_CONNECT_AS=mini-pc
PERIPHERY_CORE_PUBLIC_KEYS=file:/config/keys/core.pub
PERIPHERY_ROOT_DIRECTORY=/srv/appdata/komodo/periphery
PERIPHERY_INCLUDE_DISK_MOUNTS=/etc/hostname
