#!/bin/sh
set -e

echo "==> Starting WordPress container with auto-install..."

# Install tools
echo "==> Installing required tools..."
apk add --no-cache curl mariadb-client netcat-openbsd > /dev/null

# Download WP-CLI
if [ ! -f /usr/local/bin/wp ]; then
  echo "==> Downloading WP-CLI..."
  curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x wp-cli.phar
  mv wp-cli.phar /usr/local/bin/wp
fi

# Helper to run WP-CLI with more memory
wp() {
  php -d memory_limit=512M /usr/local/bin/wp "$@"
}

# Let the original entrypoint create wp-config.php if needed
echo "==> Preparing configuration..."
docker-entrypoint.sh true || true

# --------------------------------------------------
# Make sure WordPress core files exist
# --------------------------------------------------
if [ ! -f /var/www/html/wp-includes/version.php ]; then
  echo "==> WordPress core not found. Downloading..."
  wp core download --allow-root --force
else
  echo "==> WordPress core files already present."
fi

# Make sure wp-config.php exists
if [ ! -f /var/www/html/wp-config.php ]; then
  echo "==> Creating wp-config.php..."
  wp config create \
    --dbname="${WORDPRESS_DB_NAME}" \
    --dbuser="${WORDPRESS_DB_USER}" \
    --dbpass="${WORDPRESS_DB_PASSWORD}" \
    --dbhost="${WORDPRESS_DB_HOST}" \
    --dbprefix="${WORDPRESS_TABLE_PREFIX:-wp_}" \
    --allow-root \
    --force
fi

echo "==> Database configuration:"
echo "    Host     : ${WORDPRESS_DB_HOST}"
echo "    User     : ${WORDPRESS_DB_USER}"
echo "    Database : ${WORDPRESS_DB_NAME}"

# Wait for port
echo "==> Waiting for MariaDB port 3306..."
max_tries=30
count=0
until nc -z -w2 "${WORDPRESS_DB_HOST}" 3306 2>/dev/null; do
  count=$((count + 1))
  if [ "$count" -ge "$max_tries" ]; then
    echo "ERROR: Cannot reach ${WORDPRESS_DB_HOST}:3306"
    exit 1
  fi
  echo "    Port not open yet... ($count/$max_tries)"
  sleep 2
done
echo "==> Port 3306 is open"

# Authentication test
echo "==> Testing database authentication..."
if mariadb-admin ping \
    -h"${WORDPRESS_DB_HOST}" \
    -u"${WORDPRESS_DB_USER}" \
    -p"${WORDPRESS_DB_PASSWORD}" \
    --skip-ssl \
    --silent 2>/dev/null; then
  echo "==> Authentication SUCCESS"
else
  echo "==> Authentication FAILED"
  mariadb-admin ping \
    -h"${WORDPRESS_DB_HOST}" \
    -u"${WORDPRESS_DB_USER}" \
    -p"${WORDPRESS_DB_PASSWORD}" \
    --skip-ssl || true
  exit 1
fi

echo "==> Database is ready!"

# Install WordPress if needed
if ! wp core is-installed --allow-root 2>/dev/null; then
  echo "==> WordPress not installed yet. Running automatic installation..."

  # These variables must be provided via the environment / .env file
  if [ -z "${WORDPRESS_ADMIN_USER}" ] || [ -z "${WORDPRESS_ADMIN_PASSWORD}" ] || [ -z "${WORDPRESS_ADMIN_EMAIL}" ]; then
    echo "ERROR: WORDPRESS_ADMIN_USER, WORDPRESS_ADMIN_PASSWORD and WORDPRESS_ADMIN_EMAIL must be set"
    exit 1
  fi

  wp core install \
    --url="${WORDPRESS_URL:-https://localhost}" \
    --title="${WORDPRESS_TITLE:-Cloud-1}" \
    --admin_user="${WORDPRESS_ADMIN_USER}" \
    --admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
    --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
    --skip-email \
    --allow-root

  echo ""
  echo "========================================="
  echo "  WordPress installed successfully!"
  echo "========================================="
  echo "  URL      : ${WORDPRESS_URL:-https://localhost}"
  echo "  Title    : ${WORDPRESS_TITLE:-Cloud-1}"
  echo "  User     : ${WORDPRESS_ADMIN_USER}"
  echo "========================================="
  echo ""
else
  echo "==> WordPress is already installed. Skipping installation."
fi

# Always force the correct site URL (works for both new and existing installs)
echo "==> Ensuring correct site URL..."
wp option update home "${WORDPRESS_URL:-https://localhost}" --allow-root || true
wp option update siteurl "${WORDPRESS_URL:-https://localhost}" --allow-root || true

echo "==> Starting PHP-FPM..."
exec docker-entrypoint.sh php-fpm
