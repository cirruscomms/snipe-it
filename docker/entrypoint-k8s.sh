#!/bin/sh
set -eo pipefail

# Source Vault-injected secrets (app config only — DB creds read from files by Laravel)
set -a
. /vault/secrets/config
set +a

# Directory setup (no chown — fsGroup handles permissions)
rm -rf \
  /var/www/html/storage/private_uploads \
  /var/www/html/public/uploads \
  /var/www/html/storage/app/backups

for dir in \
  data/private_uploads \
  data/uploads/accessories \
  data/uploads/avatars \
  data/uploads/barcodes \
  data/uploads/categories \
  data/uploads/companies \
  data/uploads/components \
  data/uploads/consumables \
  data/uploads/departments \
  data/uploads/locations \
  data/uploads/maintenances \
  data/uploads/manufacturers \
  data/uploads/models \
  data/uploads/suppliers \
  dumps \
  keys
do
  [ ! -d "/var/lib/snipeit/$dir" ] && mkdir -p "/var/lib/snipeit/$dir"
done

# Symlinks
ln -fs /var/lib/snipeit/data/private_uploads /var/www/html/storage/private_uploads
ln -fs /var/lib/snipeit/data/uploads /var/www/html/public/uploads
ln -fs /var/lib/snipeit/dumps /var/www/html/storage/app/backups
ln -fs /var/lib/snipeit/keys/oauth-public.key /var/www/html/storage/oauth-public.key
ln -fs /var/lib/snipeit/keys/oauth-private.key /var/www/html/storage/oauth-private.key

# OAuth migrations
if [ ! -f /var/www/html/database/migrations/*create_oauth* ]; then
  cp -a /var/www/html/vendor/laravel/passport/database/migrations/* /var/www/html/database/migrations/
fi

# Log file
touch /var/www/html/storage/logs/laravel.log

# Run migrations (skip for scheduler mode)
if [ "${MODE}" != "scheduler" ]; then
  php artisan migrate --force
  php artisan config:clear
fi

# Exec based on mode
if [ "${MODE}" = "scheduler" ]; then
  exec php artisan schedule:work
else
  exec "$@"
fi
