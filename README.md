# Cloud-1 – Automated WordPress Stack Deployment

Fully automated deployment of a production-ready **WordPress** environment using **Ansible** + **Docker Compose**.

One command deploys a complete, secured, persistent stack on a fresh Ubuntu 22.04 server (local Multipass VM or cloud instance).

---

## Stack Overview

| Service        | Image                         | Purpose                          | Exposed            |
|----------------|-------------------------------|----------------------------------|--------------------|
| **nginx**      | `nginx:1.25-alpine`           | Reverse proxy + TLS termination  | Ports 80 & 443     |
| **wordpress**  | `wordpress:php8.2-fpm-alpine` | WordPress (PHP-FPM) + auto-install | Internal only    |
| **mariadb**    | `mariadb:11.2`                | Database                         | Internal only      |
| **phpmyadmin** | `phpmyadmin:5.2-apache`       | Database administration UI       | Via nginx only     |

### Key Features
- One process = one container
- Named Docker volumes → data survives reboots and container recreation
- `restart: always` on every service
- Firewall (UFW) allows **only** ports 22 / 80 / 443
- Self-signed TLS certificates (generated automatically)
- WordPress installed and configured automatically via WP-CLI
- Secrets managed with Ansible Vault (no hard-coded secrets)
- Idempotent Ansible roles

---

## Requirements

### Control machine (your laptop)
- Ansible ≥ 2.14
- Required collections:
  ```bash
  ansible-galaxy collection install community.docker community.general ansible.posix
  ```
- SSH private key with access to the target
- (Optional) Multipass for local testing

### Target server
- Fresh **Ubuntu 22.04 LTS**
- SSH access + Python 3
- Sufficient resources (recommended: 2 vCPU, 4 GB RAM, 20 GB disk)

---

## Quick Start (for evaluation)

### 1. Configure the inventory
Edit `ansible/inventory/hosts.yml`:

```yaml
all:
  children:
    cloud1:
      hosts:
        server1:
          ansible_host: <IP-or-hostname>
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/your-key.pem
```

### 2. Configure non-secret variables (optional)
Edit `ansible/group_vars/all/all.yml` if needed (domain, timezone…).

### 3. Set secrets (Ansible Vault)
```bash
cd ansible
ansible-vault edit group_vars/all/vault.yml
```

Example content:
```yaml
vault_wordpress_admin_user: "admin"
vault_wordpress_admin_password: "ChangeMeStrongPassword!"
vault_wordpress_admin_email: "admin@example.com"
```

Create the vault password file (path defined in `ansible.cfg`):
```bash
echo "your-vault-password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass
```

### 4. Prepare Docker environment file
```bash
cp docker/.env.example docker/.env
# Edit docker/.env and set strong passwords for the database
```

### 5. Deploy
```bash
cd ansible
ansible-playbook site.yml
```

Useful tags (for partial / modular runs):
```bash
ansible-playbook site.yml --tags common
ansible-playbook site.yml --tags docker
ansible-playbook site.yml --tags firewall
ansible-playbook site.yml --tags deploy
```

---

## Access the Application

After successful deployment:

| Service      | URL                              |
|--------------|----------------------------------|
| WordPress    | `https://<server-ip>`            |
| phpMyAdmin   | `https://<server-ip>/phpmyadmin/`|

Credentials are the ones you set in the vault / `.env` file.

> Accept the self-signed certificate warning in your browser.

---

## Project Structure

```
cloud-deploy/
├── ansible/
│   ├── ansible.cfg
│   ├── site.yml                    # Main playbook
│   ├── inventory/
│   │   └── hosts.yml
│   ├── group_vars/
│   │   └── all/
│   │       ├── all.yml             # Non-secret variables
│   │       └── vault.yml           # Secrets (encrypted)
│   └── roles/
│       ├── common/                 # System packages, timezone
│       ├── docker/                 # Install Docker + Compose
│       ├── firewall/               # UFW (22/80/443 only)
│       └── deploy/                 # Sync files, generate certs, start stack
├── docker/
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── nginx/
│   │   └── conf.d/default.conf
│   └── wordpress/
│       └── init-wordpress.sh       # Auto-install script
├── README.md
└── ...
```

---

## Local Testing with Multipass

```bash
# Launch VM
multipass launch 22.04 --name cloud1 --cpus 2 --memory 4G --disk 20G

# Inject your SSH public key
multipass exec cloud1 -- bash -c 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'
multipass exec cloud1 -- bash -c "cat >> ~/.ssh/authorized_keys" < ~/.ssh/id_ed25519.pub
multipass exec cloud1 -- chmod 600 ~/.ssh/authorized_keys

# Get IP
multipass info cloud1
```

Then update `ansible/inventory/hosts.yml` with the IP and your private key path.

---

## Persistence Test

```bash
# Stop and start the VM / server
multipass stop cloud1
multipass start cloud1

# Containers and all data (WordPress + database) come back automatically
```

---

## Security Notes

- Only ports **22**, **80** and **443** are open
- MariaDB and phpMyAdmin are **not** exposed to the internet
- TLS is enforced (HTTP → HTTPS redirect)
- Secrets are stored in Ansible Vault (no hard-coded secrets in the code)
- Docker `.env` file has restricted permissions (`0600`)
- Self-signed certificates are generated on the target (replace with real ones for production)

---

## Notes for Evaluation / Production

- Fully automated — only a clean Ubuntu 22.04 + SSH + Python is required
- Data persists across reboots (named volumes + restart policies)
- Firewall is restrictive by default
- Database is never reachable from the outside
- Ansible roles are clearly separated and idempotent
- Works on any fresh Ubuntu 22.04 instance (Multipass, AWS EC2, etc.)
- On AWS: ensure the Security Group allows inbound TCP 22, 80 and 443

---

## Troubleshooting

| Problem                        | Possible solution                                      |
|--------------------------------|--------------------------------------------------------|
| Vault password error           | Check `vault_password_file` path in `ansible.cfg`     |
| Permission denied on Docker    | Re-run after the `docker` role (user is added to group)|
| Certificate warning            | Expected with self-signed certs                        |
| Containers not starting        | Check `docker compose logs` on the target              |
| Ansible connection issues      | Verify IP, user and private key path in inventory      |

---

Made for the **Cloud-1 / Inception** project.
