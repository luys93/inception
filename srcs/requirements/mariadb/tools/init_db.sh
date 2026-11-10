#!/bin/bash

set -e

# cartella del socket: deve esistere anche quando il bootstrap viene saltato
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

# escape per stringhe SQL tra apici: \ -> \\ e ' -> ''
sql_escape() {
    local s="${1//\\/\\\\}"
    printf '%s' "${s//\'/\'\'}"
}

INIT_ARGS=()

# bootstrap quando il database non esiste (primo avvio o MYSQL_DATABASE cambiato)
# niente server temporaneo in background: mysqld esegue il file SQL all'avvio
if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
    DB="${MYSQL_DATABASE//\`/\`\`}"
    USER="$(sql_escape "${MYSQL_USER}")"
    PASS="$(sql_escape "${MYSQL_PASSWORD}")"
    ROOT_PASS="$(sql_escape "${MYSQL_ROOT_PASSWORD}")"

    cat > /tmp/init.sql <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB}\`;
CREATE USER IF NOT EXISTS '${USER}'@'%' IDENTIFIED BY '${PASS}';
GRANT ALL ON \`${DB}\`.* TO '${USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';
FLUSH PRIVILEGES;
EOF
    chown mysql:mysql /tmp/init.sql
    chmod 600 /tmp/init.sql
    INIT_ARGS=(--init-file=/tmp/init.sql)
fi

exec mysqld --bind-address=0.0.0.0 --port="${DB_PORT}" --user=mysql "${INIT_ARGS[@]}"
