#!/bin/bash

set -e

cd /var/www/html

wait_for_db() {
    local max_attempts=30
    local attempt=1
    echo "Waiting for MariaDB (max ${max_attempts} attempts)..."
    while [ "$attempt" -le "$max_attempts" ]; do
        if MYSQL_PWD="${MYSQL_PASSWORD}" mysqladmin ping -P "${DB_PORT}" -h mariadb -u "${MYSQL_USER}" --silent >/dev/null 2>&1; then
            echo "MariaDB is up!"
            return 0
        fi
        echo "Attempts $attempt/$max_attempts: MariaDB not ready yet..." 
        sleep 1
        attempt=$((attempt + 1))
    done
    echo "Failed to connect to MariaDB after $max_attempts attemps."
    return 1
}

wait_for_db || exit 1

#if [ ! -f /var/www/html/"wp-config.php" ]; then

if [ ! -f /var/www/html/"wp-load.php" ]; then
    echo "Downloading Wordpress..."
    wp core download --allow-root
fi

if  [ ! -f /var/www/html/"wp-config.php" ]; then
    echo "Configuring wp-config-php..."
    wp config create --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="mariadb:${DB_PORT}"
fi

# wp-config.php sta nel volume: riallinea la porta del db a ogni avvio
wp config set DB_HOST "mariadb:${DB_PORT}" --allow-root

if ! wp core is-installed --allow-root 2>/dev/null; then
    echo "Installing Wordpress..."
    wp core install --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_AD_USER}" \
        --admin_password="${WP_AD_PASSWORD}" \
        --admin_email="${WP_AD_EMAIL}"
fi

if ! wp user get "${WP_USER}" --allow-root >/dev/null 2>&1; then
    echo "Creating regular user..."
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=author \
        --allow-root
fi

# i commenti degli utenti registrati vengono pubblicati subito, senza moderazione
wp option update comment_previously_approved 0 --allow-root

# URL del sito coerente con la porta di nginx (niente ":443" se e' quella standard)
URL="https://${DOMAIN_NAME}"
if [ "${NGINX_PORT}" != "443" ]; then
    URL="${URL}:${NGINX_PORT}"
fi
wp option update home "${URL}" --allow-root
wp option update siteurl "${URL}" --allow-root

# porta su cui ascolta php-fpm
sed -i "s/^listen = .*/listen = 0.0.0.0:${WP_PORT}/" /etc/php/8.2/fpm/pool.d/www.conf

chown -R www-data:www-data /var/www/html

echo "Starting PHP-FPM..."
exec php-fpm8.2 -F