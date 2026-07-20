# Cloud-1 – Docker Compose for Cloud-1

Automated WordPress stack ready for Ansible deployment.

## Services

| Service     | Image                        | Role                          | Exposed |
|-------------|------------------------------|-------------------------------|---------|
| nginx       | nginx:1.25-alpine            | Reverse proxy + TLS           | 80, 443 |
| wordpress   | wordpress:php8.2-fpm-alpine  | WordPress (PHP-FPM)           | internal|
| mariadb     | mariadb:11.2                 | Database                      | internal|
| phpmyadmin  | phpmyadmin:5.2-apache        | Database admin UI             | internal|

## Requirements satisfied

- ✅ 1 process = 1 container
- ✅ Containers communicate on internal Docker network (`cloud1`)
- ✅ Only ports 80 / 443 exposed (SSH 22 is on the host)
- ✅ Database **not** reachable from the internet
- ✅ Data persistence via named volumes (`wordpress_data`, `db_data`)
- ✅ Automatic restart (`restart: always`)
- ✅ TLS enabled (self-signed certificates included)
- ✅ URL-based routing:
  - `https://<host>/` → WordPress
  - `https://<host>/phpmyadmin` → phpMyAdmin
- ✅ Official Docker images
- ✅ Ready for multi-host parallel deployment (each host has its own volumes)

## Quick start (local test)

```bash
# 1. Edit secrets
cp .env .env.local   # or just edit .env
# Change all passwords!

# 2. Start the stack
docker compose up -d

# 3. Check status
docker compose ps

# 4. Access
# WordPress  → https://localhost
# phpMyAdmin → https://localhost/phpmyadmin
```

> Browser will warn about the self-signed certificate – this is expected.

## Important files

```
.
├── docker-compose.yml      # Main orchestration file
├── .env                    # Secrets & configuration (DO NOT commit real secrets)
├── nginx/
│   └── conf.d/
│       └── default.conf    # Nginx routing + TLS config
└── certs/
    ├── fullchain.pem       # Self-signed certificate
    └── privkey.pem         # Private key
```

## Production notes (for Ansible)

- Replace self-signed certificates with real ones (Let’s Encrypt / certbot or your provider).
- Never commit the real `.env` – use Ansible Vault or `env` injection.
- The stack is portable: it works on any fresh Ubuntu 22.04 with Docker + Compose.
- Volumes survive container and host reboots (as long as Docker is configured to start on boot).

## Changing domain / certificates

1. Put your real `fullchain.pem` and `privkey.pem` in `./certs/`
2. Update `DOMAIN_NAME` in `.env` if needed
3. `docker compose up -d --force-recreate nginx`
