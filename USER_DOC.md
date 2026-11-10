# User Documentation

## Services provided

The stack hosts a **WordPress website** served over HTTPS. It is made of three
containers:

- **nginx**: the web server and the only entry point (HTTPS on port 443).
- **wordpress**: runs WordPress with PHP-FPM.
- **mariadb**: stores the website data (posts, pages, users, comments).

## Start and stop the project

Run these commands from the root of the repository:

| Action                                 | Command       |
|----------------------------------------|---------------|
| Build and start everything             | `make`        |
| Stop the containers (keep them)        | `make stop`   |
| Start the stopped containers           | `make start`  |
| Stop and remove the containers         | `make down`   |
| Remove everything, including all data  | `make fclean` |

> ⚠️ `make clean` and `make fclean` delete the website data and the database.

## Access the website and the administration panel

1. Make sure `/etc/hosts` contains `127.0.0.1   lluciani.42.fr`.
2. Open **https://lluciani.42.fr**. The certificate is self-signed, so accept the
   browser warning.
3. To reach the administration panel, open **https://lluciani.42.fr/wp-admin**
   and log in with the administrator account.

The site is only available over HTTPS: `http://lluciani.42.fr` does not respond.

## Credentials

Credentials are stored in **`srcs/.env`**. This file is not in the git
repository and must be created locally.

| Account               | Variables                                               |
|-----------------------|---------------------------------------------------------|
| WordPress administrator | `WP_AD_USER`, `WP_AD_PASSWORD`, `WP_AD_EMAIL`         |
| WordPress regular user  | `WP_USER`, `WP_USER_PASSWORD`, `WP_USER_EMAIL`        |
| Database user           | `MYSQL_USER`, `MYSQL_PASSWORD` (database `MYSQL_DATABASE`) |

To change a WordPress password, use the administration panel (*Users → Profile*).
Editing `.env` afterwards has no effect on an existing installation, because
users are only created on the first start.

## Check that the services are running

```bash
make ps                        # all three containers should be "Up"
docker logs nginx              # logs of a single service
docker logs wordpress
docker logs mariadb
```

Quick checks:

- Open https://lluciani.42.fr: the WordPress home page should appear, not the
  installation page.
- Run `curl -k -I https://lluciani.42.fr`: the response should be `HTTP/1.1 200 OK`.
- Run `docker exec -it mariadb mariadb -u root -p -e "SHOW DATABASES;"`: the WordPress
  database should be listed.
