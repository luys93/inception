# Developer Documentation

## Set up the environment from scratch

### Prerequisites

- A Linux virtual machine (Debian or Ubuntu) with a user named `lluciani`.
- Docker Engine and the Docker Compose plugin (`docker compose version`).
- `make`, and `sudo` rights (needed by `make clean` and `make fclean`).
- The local domain in `/etc/hosts`:
  ```bash
  echo "127.0.0.1   lluciani.42.fr" | sudo tee -a /etc/hosts
  ```

### Configuration files

```
.
├── Makefile
└── srcs/
    ├── .env                    # local only, ignored by git
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/   (Dockerfile, tools/init_db.sh)
        ├── wordpress/ (Dockerfile, conf/www.conf, tools/setup_wordpress.sh)
        └── nginx/     (Dockerfile, conf/nginx.conf, tools/setup.sh, tools/entrypoint.sh)
```

### Secrets: the `.env` file

The `.env` file holds every credential and is **never committed**: it is listed
in `srcs/.gitignore`. After cloning, create `srcs/.env` with the following
variables:

```env
DOMAIN_NAME=lluciani.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=<db_user>
MYSQL_PASSWORD=<db_password>
MYSQL_ROOT_PASSWORD=<db_root_password>

WP_TITLE=inception
WP_AD_USER=<admin_login>          # must NOT contain "admin" / "Admin"
WP_AD_PASSWORD=<admin_password>
WP_AD_EMAIL=<admin_email>

WP_USER=<user_login>
WP_USER_PASSWORD=<user_password>
WP_USER_EMAIL=<user_email>

NGINX_PORT=443                    # port published by nginx (HTTPS)
WP_PORT=9000                      # port php-fpm listens on
DB_PORT=3306                      # port mariadb listens on
```

Docker Compose loads this file into the `mariadb` and `wordpress` containers
through `env_file`. The `nginx` container only receives `NGINX_PORT` and
`WP_PORT` through `environment`, so it never sees any credential.

## Build and launch

The `Makefile` wraps Docker Compose and always uses `srcs/docker-compose.yml`:

| Target        | What it does                                                                 |
|---------------|------------------------------------------------------------------------------|
| `make` / `all`| Creates `/home/lluciani/data/{wordpress,mariadb}`, then runs `docker compose up -d --build` |
| `make down`   | `docker compose down`: stops and removes the containers and the network      |
| `make stop`   | Stops the containers without removing them                                   |
| `make start`  | Starts the stopped containers                                                |
| `make ps`     | Shows the container status                                                   |
| `make re`     | `down` followed by `all`                                                     |
| `make clean`  | `down`, then empties the data folders                                        |
| `make fclean` | `clean`, then removes the volumes, the images of the three services (`--rmi all`) and the data folder |

On the first start the services do the following:

1. **mariadb** initialises `/var/lib/mysql`, writes `/tmp/init.sql` (database,
   user, root password) and runs `mysqld` in the foreground with
   `--init-file=/tmp/init.sql`. On later starts the database already exists and
   `mysqld` starts without the init file.
2. **wordpress** waits until MariaDB answers (at most 30 attempts). It then uses
   WP-CLI to download WordPress, create `wp-config.php`, install the site and
   create the second user, and finally runs `php-fpm8.2 -F`.
3. **nginx** builds `/etc/nginx/nginx.conf` from the template with `envsubst`
   (only `${NGINX_PORT}` and `${WP_PORT}` are replaced), serves `/var/www/html`
   and forwards `*.php` requests to `wordpress:${WP_PORT}`. The TLS certificate
   is generated when the image is built.

## Useful commands

```bash
# Containers
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs -f <service>
docker compose -f srcs/docker-compose.yml build --no-cache <service>
docker exec -it <container> bash

# Network
docker network ls
docker network inspect srcs_inception

# Volumes
docker volume ls
docker volume inspect srcs_wordpress_data
docker volume inspect srcs_mariadb_data

# Database
docker exec -it mariadb mariadb -u root -p          # root login (MYSQL_ROOT_PASSWORD)
docker exec -it mariadb mariadb -u root -p -e "USE wordpress; SHOW TABLES;"
docker exec -it mariadb mariadb -u root -p -e "SELECT user_login FROM wordpress.wp_users;"

# TLS check
openssl s_client -connect lluciani.42.fr:443 -tls1_2 </dev/null
```

The project name, and therefore the prefix of network and volume names, comes
from the `srcs` folder. Check the exact names with `docker network ls` and
`docker volume ls`.

## Data storage and persistence

The project uses two Docker **named volumes**, defined in `docker-compose.yml`
with the `local` driver and `driver_opts` so that their data lives on the host:

| Volume           | Mounted in                               | Host path                        |
|------------------|------------------------------------------|----------------------------------|
| `wordpress_data` | `/var/www/html` (wordpress and nginx)    | `/home/lluciani/data/wordpress`  |
| `mariadb_data`   | `/var/lib/mysql` (mariadb)               | `/home/lluciani/data/mariadb`    |

The data lives on the host, so it survives `make down`, a container rebuild and
a reboot of the virtual machine. After a reboot, run `make` again: the setup
scripts detect the existing installation and skip the initialisation.

Only `make clean` and `make fclean` delete the data.
