
# Cloud-1 – Automated Deployment of Inception

Automated deployment of a complete WordPress stack using **Ansible** + **Docker Compose**.

## Stack

| Service     | Image                        | Role                     |
|-------------|------------------------------|--------------------------|
| nginx       | nginx:1.25-alpine            | Reverse proxy + TLS      |
| wordpress   | wordpress:php8.2-fpm-alpine  | WordPress (PHP-FPM)      |
| mariadb     | mariadb:11.2                 | Database                 |
| phpmyadmin  | phpmyadmin:5.2-apache        | Database administration  |

- 1 process = 1 container
- Named volumes for data persistence
- `restart: always`
- Only ports **22 / 80 / 443** are open
- TLS enabled (self-signed certificates)

## Requirements

### Control machine
- Ansible ≥ 2.14
- Collections:
  ```bash
  ansible-galaxy collection install community.docker community.general ansible.posix
  ```
- SSH key pair
- Multipass (for local testing) or any Ubuntu 22.04 server

### Target
- Fresh Ubuntu 22.04 LTS
- SSH access + Python 3

## Quick start with Multipass

```bash
# Launch the VM
multipass launch 22.04 --name cloud1 --cpus 2 --memory 4G --disk 20G

# Inject your SSH key
multipass exec cloud1 -- bash -c 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'
multipass exec cloud1 -- bash -c "cat >> ~/.ssh/authorized_keys" < ~/.ssh/id_cloud1.pub
multipass exec cloud1 -- chmod 600 ~/.ssh/authorized_keys

# Get the IP
multipass info cloud1
```

Update `ansible/inventory/hosts.yml` with the IP and key path.

## Configuration

Edit `ansible/group_vars/all.yml`:

```yaml
wordpress_url: "https://{{ ansible_host }}"
wordpress_admin_user: "admin"
wordpress_admin_password: "admin123"          # change this!
wordpress_admin_email: "admin@example.com"
wordpress_title: "Cloud-1"
```

Also configure `docker/.env` (copy from `.env.example` and set strong passwords).

## Deploy

```bash
cd ansible
ansible-playbook site.yml
```

Useful tags:

```bash
ansible-playbook site.yml --tags docker
ansible-playbook site.yml --tags firewall
ansible-playbook site.yml --tags deploy
```

## Access

- **WordPress**: `https://<IP>`
- **phpMyAdmin**: `https://<IP>/phpmyadmin/`

Default credentials (change them!):

| Service    | User  | Password   |
|------------|-------|------------|
| WordPress  | admin | admin123   |
| phpMyAdmin | root  | (see .env) |

> Accept the self-signed certificate warning in your browser.

## Project structure

```
.
├── ansible/
│   ├── group_vars/all.yml
│   ├── inventory/hosts.yml
│   ├── roles/
│   │   ├── common/
│   │   ├── docker/
│   │   ├── firewall/
│   │   └── deploy/
│   └── site.yml
└── docker/
    ├── docker-compose.yml
    ├── .env / .env.example
    ├── nginx/
    ├── wordpress/
    └── certs/
```

## Persistence test

```bash
multipass stop cloud1
multipass start cloud1
# Containers and data should come back automatically
```

## Notes for evaluation

- Fully automated (only Ubuntu 22.04 + SSH + Python required)
- Data survives reboot (named volumes + restart policies)
- Firewall locks everything except 22/80/443
- Database is never exposed to the internet
- Ansible code is organized into clear roles
- Portable to any fresh Ubuntu 22.04 instance