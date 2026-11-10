*This project has been created as part of the 42 curriculum by lluciani.*

# Inception

## Description

Inception is a system administration project whose goal is to build a small web
infrastructure using **Docker** and **Docker Compose**, inside a virtual machine.

The stack is made of three services, each running in its own container built from
a custom Dockerfile based on `debian:bookworm` (the penultimate stable Debian release):

| Service     | Role                                                          | Port (internal) |
|-------------|---------------------------------------------------------------|-----------------|
| `nginx`     | Only entry point of the infrastructure, HTTPS with TLSv1.2/1.3 | 443 (published) |
| `wordpress` | WordPress + PHP-FPM (no web server inside)                    | 9000            |
| `mariadb`   | Database used by WordPress                                    | 3306            |

```
            HTTPS :443
 Browser ───────────────► nginx ──FastCGI :9000──► wordpress ──SQL :3306──► mariadb
                            │                         │                       │
                            └──── wordpress_data ─────┘                 mariadb_data
```

The website is reachable at `https://lluciani.42.fr`.

### Use of Docker and sources included

Every service has its own folder in `srcs/requirements/`:

- `mariadb/`
  - `Dockerfile`: installs `mariadb-server`.
  - `tools/init_db.sh`: on first start it initialises the data directory and
    writes an SQL file that creates the database and the WordPress user and sets
    the root password. It then runs `mysqld` in the foreground as PID 1 with
    `--init-file`, so no temporary server is ever started in the background.
- `wordpress/`
  - `Dockerfile`: installs PHP-FPM 8.2, its extensions and WP-CLI.
  - `conf/www.conf`: PHP-FPM pool configuration. The `listen` line is rewritten
    at startup by `setup_wordpress.sh` (with `sed`) so that PHP-FPM listens on
    `0.0.0.0:${WP_PORT}` (9000 by default).
  - `tools/setup_wordpress.sh`: waits for MariaDB, then downloads, configures
    and installs WordPress and creates the two users. Finally it starts
    `php-fpm8.2 -F` in the foreground.
- `nginx/`
  - `Dockerfile`: installs NGINX and OpenSSL.
  - `tools/setup.sh`: generates a self-signed certificate at build time.
  - `conf/nginx.conf`: a **template**, copied into the image as
    `/etc/nginx/nginx.conf.template`. It listens on `${NGINX_PORT}` (443) with
    TLSv1.2/TLSv1.3 only and forwards PHP requests to `wordpress:${WP_PORT}` (9000).
  - `tools/entrypoint.sh`: at container start it runs `envsubst` on the template,
    replacing **only** `${NGINX_PORT}` and `${WP_PORT}` (so NGINX's own variables
    like `$uri` stay untouched), writes `/etc/nginx/nginx.conf` and then starts
    `nginx -g "daemon off;"` with `exec`, so NGINX is PID 1.

`srcs/docker-compose.yml` defines the three services, the `inception` bridge
network and the two named volumes. The `Makefile` at the root builds and starts
everything through Docker Compose.

### Main design choices

- **Debian bookworm** as base image for every container. No ready-made images
  are pulled from Docker Hub.
- **One process per container, in the foreground (PID 1).** Each entrypoint
  ends with `exec`, so the main daemon receives Docker's signals. No
  `tail -f`, `sleep infinity` or infinite loops are used.
- **WP-CLI** automates the WordPress installation, so the installation page is
  never shown.
- **Idempotent setup scripts.** Every step checks whether it has already been
  done, so restarting a container does not reinstall anything.
- **Images are tagged `inception`.** The images are named after their service
  (`mariadb:inception`, `wordpress:inception`, `nginx:inception`) and never use
  the `latest` tag.
- **`restart: always`.** Containers are restarted automatically after a crash
  (and after a reboot of the VM, as soon as the Docker daemon starts).

### Virtual Machines vs Docker

A **virtual machine** emulates a full computer: it runs its own kernel on top of
a hypervisor. That makes it heavy (gigabytes, minutes to boot) but strongly
isolated.

A **Docker container** shares the host kernel and isolates processes using
namespaces and cgroups. Containers are lightweight (megabytes) and start in
seconds. They are also reproducible: the same image runs the same way
everywhere.

In this project the VM provides the isolated environment, and Docker runs each
service inside it.

### Secrets vs Environment Variables

**Environment variables** are easy to use: they are passed to the container and
read by scripts. However, they are visible through `docker inspect` and in the
process environment.

**Docker secrets** are mounted as files (in `/run/secrets/`) only inside the
containers that need them, and are not exposed in the container configuration.
This makes them better suited to passwords.

In this project configuration and credentials are stored in `srcs/.env`, which is
ignored by git and never committed.

### Docker Network vs Host Network

With the **host network** a container shares the host network stack directly.
There is no isolation and ports can clash with the host.

A **Docker (bridge) network** creates a private virtual network. Containers on it
reach each other by service name through Docker's internal DNS (for example
`mariadb:3306`), and only the ports explicitly published are reachable from
outside.

Here every service is on the `inception` network, and only NGINX publishes a
port (443).

### Docker Volumes vs Bind Mounts

A **bind mount** maps an arbitrary host path into a container. It depends on the
host directory structure and is not managed by Docker.

A **named volume** is created and managed by Docker (`docker volume ls`,
`docker volume inspect`). It has a name, can be shared between containers and
survives container removal.

This project uses two named volumes, `wordpress_data` and `mariadb_data`. They
use the `local` driver configured with `driver_opts` so that their data is
stored in `/home/lluciani/data` on the host.

## Instructions

### Prerequisites

- A Linux virtual machine with `docker`, the `docker compose` plugin and `make`.
- The domain pointing to the local machine. Add this line to `/etc/hosts`:
  ```
  127.0.0.1   lluciani.42.fr
  ```
- A `srcs/.env` file with the configuration (see [DEV_DOC.md](DEV_DOC.md)).

### Build and run

```bash
make          # create data folders, build images, start containers
make ps       # show container status
make stop     # stop containers
make start    # start them again
make down     # stop and remove containers
make fclean   # remove containers, volumes, data and images
make re       # stop and rebuild/restart the containers (data is kept)
```

Then open `https://lluciani.42.fr` in a browser and accept the self-signed
certificate warning.

More details: [USER_DOC.md](USER_DOC.md) for users, [DEV_DOC.md](DEV_DOC.md) for developers.

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Dockerfile best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Docker volumes](https://docs.docker.com/storage/volumes/) and [networking](https://docs.docker.com/network/)
- [NGINX documentation](https://nginx.org/en/docs/) and [ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [WP-CLI commands](https://developer.wordpress.org/cli/commands/)
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/)
- [What is PID 1 and why it matters in containers](https://cloud.google.com/architecture/best-practices-for-building-containers#signal-handling)

### Use of AI

AI was used as a learning and review aid, not to generate the project as a whole.
Every piece of configuration and every script was written, tested and understood
by me before being kept.

- **Understanding concepts**: explanations of how NGINX talks to PHP-FPM through
  FastCGI (`try_files`, `fastcgi_pass`), PID 1 and why the final process is started
  with `exec`, named volumes vs bind mounts, and Docker networks.
- **Debugging**: interpreting error messages while building and starting the
  containers (e.g. MariaDB bootstrap and WordPress waiting for the database).

All AI suggestions were checked against the official documentation listed above
and tested in the virtual machine.
