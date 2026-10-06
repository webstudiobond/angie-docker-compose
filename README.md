# Hardened Containerized Edge Angie

[![CI](https://github.com/webstudiobond/angie-docker-compose/actions/workflows/ci.yml/badge.svg)](https://github.com/webstudiobond/angie-docker-compose/actions/workflows/ci.yml)
[![GitHub last commit](https://img.shields.io/github/last-commit/webstudiobond/angie-docker-compose)](https://github.com/webstudiobond/angie-docker-compose/commits/main)
[![GitHub issues](https://img.shields.io/github/issues/webstudiobond/angie-docker-compose)](https://github.com/webstudiobond/angie-docker-compose/issues)
[![GitHub repo size](https://img.shields.io/github/repo-size/webstudiobond/angie-docker-compose)](https://github.com/webstudiobond/angie-docker-compose)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A zero-privilege perimeter reverse proxy and TLS gateway based on [Angie](https://en.angie.software/). It serves as an isolated edge entry point for multi-tenant containerized workloads—such as [wordpress-docker](https://github.com/webstudiobond/wordpress-docker) and [speedybench](https://github.com/underhax/speedybench)—communicating over a dedicated internal Docker network (`frontend_gateway`).

## Motivation

Most Docker Compose guides and deployment setups for Angie prioritize rapid initial setup over operational security. In practice, this promotes patterns that compromise host isolation and leave the edge under-configured:

* **Host Port Exposure:** Workloads are routinely configured to publish ports directly to the host network—even when bound to `127.0.0.1`—breaking container network isolation, risking port collisions, and exposing internal application tiers to the host network stack.
* **Insecure Container Runtimes:** Typical setups execute edge proxies as root, retain all Linux capabilities, keep container filesystems fully writable, and run without CPU or memory limits, significantly amplifying the blast radius of any web exploit.
* **Inadequate Default Configurations:** Stock Angie container images provide only bare-minimum configuration stubs, lacking critical perimeter protections such as trusted Cloudflare real client IP validation, security response headers, and RFC 8470 0-RTT anti-replay mitigation.
* **Perimeter Fingerprinting & Information Leakage:** Default error handling regularly exposes backend server signatures, PHP versions, and raw upstream error traces during outages, simplifying automated reconnaissance.

## Architecture Highlights

* **Closed-Circuit Multi-Tenant Network:** Provisions and manages the isolated `frontend_gateway` network on subnet `172.20.0.0/16`. Internal tenant containers such as `${SITE_USER}_angie` from `wordpress-docker` and `speedybench` attach to this network with zero exposed host ports.
* **Zero-Privilege Security Profile:** Operates under a dedicated unprivileged non-root user with an immutable read-only filesystem, strips all Linux kernel capabilities except binding privileged network ports, prevents privilege escalation, and enforces strict CPU and memory resource limits.
* **Decoupled Hardened Configuration Suite:** Replaces minimal stock container stubs with fully externalized, read-only host configurations—including extended MIME type mappings, dynamic module declarations, and modular protocol snippets—guaranteeing deterministic edge behavior and total control over runtime settings.
* **Native In-Process ACME:** Built-in Let's Encrypt certificate issuance and automated renewal directly within Angie using `acme_client`, eliminating separate certbot containers, cron jobs, and external ACME socket mounts.
* **HTTP/3 & Modern Transport Security:** Native HTTP/3 over QUIC/UDP 443 and HTTP/2, TLS 1.3/1.2 with custom Diffie-Hellman parameters, MTU-tuned 1369-byte TLS record sizing, session resumption, and RFC 8470 compliant 0-RTT anti-replay attack mitigation, among other transport hardening controls.
* **Automated Cloudflare Real IP Synchronization:** Dedicated host script and cron job fetch official Cloudflare IPv4/IPv6 CIDRs, configure trusted proxy ranges for real client IP restoration via the `CF-Connecting-IP` header, perform container syntax validation, and trigger graceful reloads under an exclusive lock.
* **Perimeter Hardening & Zero Information Leakage:** Universal baseline security headers with per-domain CSP customization, and anonymous perimeter error pages that eliminate reconnaissance by preventing leakage of server signatures, PHP versions, or OS details.
* **Dynamic Compression & Module Extensibility:** Brotli and Zstandard dynamic compression modules are enabled by default alongside standard Gzip, with the ability to activate any additional pre-compiled dynamic module from the official Angie image via `modules.conf`.
* **Zero-Downtime Host Log Rotation:** Systemd-driven host logrotate configuration rotates container logs daily with gzip compression and signals Angie via `USR1` to reopen descriptors without dropping active connections.

---

<details>
<summary><strong>Production Directory Structure</strong></summary>

```text
/
├── etc/
│   ├── cron.d/
│   │   └── update-cf-ips            # Weekly Cloudflare IP updater cron job
│   └── logrotate.d/
│       └── angie                    # Angie logrotate configuration
├── usr/local/bin/
│   ├── angie                        # Angie container CLI wrapper script
│   └── update-cf-ips.sh             # Cloudflare IP fetch and reload script
└── home/angie/                      # Dedicated non-root user home directory
    ├── docker-compose.yaml          # Production stack deployment manifest
    ├── .env                         # Host environment variables file
    └── data/                        # Persistent Angie runtime data and configuration
        ├── angie.conf               # Main Angie server configuration
        ├── mime.types               # Extended MIME type mappings
        ├── modules.conf             # Dynamic modules configuration
        ├── certs/                   # ACME Let's Encrypt certificates
        ├── cache/                   # Proxy cache storage
        ├── html/                    # Static HTML files
        ├── ssl/                     # SSL configuration directory
        │   └── dhparam.pem          # Generated Diffie-Hellman parameters
        ├── logs/                    # Angie system error logs
        │   └── domains/             # Per-domain access and error logs
        └── conf.d/                  # Configuration snippets and virtual hosts
            ├── 0rtt-anti-replay.conf    # TLS 1.3 0-RTT replay attack mitigation
            ├── cloudflare-ips.inc       # Trusted Cloudflare IP ranges generated via script
            ├── error-pages.inc          # Perimeter error pages
            ├── healthcheck.inc          # Container healthcheck endpoint
            ├── http-protocols.conf      # HTTP/2 and HTTP/3 activation directives
            ├── security-headers.inc     # Security response headers
            └── domains/                 # Per-domain virtual host configurations
                └── <site_user>.conf     # Deployed virtual host configuration
```

</details>

---

<details>
<summary><strong>Deployment &amp; Setup</strong></summary>

### Prerequisites

* **Docker Engine & Compose:** Ensure Docker Engine and Docker Compose plugin are installed on the host. Follow the official installation guide for [Ubuntu](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository).
* **Network Ports:** The host must have ports `80/tcp`, `443/tcp`, and `443/udp` (for HTTP/3 QUIC) open and not occupied by other services.

### 1. Create a Dedicated System User

Define the desired UID and GID (defaulting to `2001`, or customize as needed for your system) and verify they are not already allocated on the host:

```bash
APP_UID=2001
APP_GID=2001

getent passwd ${APP_UID}
getent group ${APP_GID}
```

If neither command produces output, create the system group and user with a disabled login shell:

```bash
sudo groupadd -g ${APP_GID} angie
sudo useradd -m -d /home/angie -s /usr/sbin/nologin -u ${APP_UID} -g ${APP_GID} angie
```

### 2. Create Directory Structure

```bash
sudo -u angie mkdir -p /home/angie/data/{cache,certs,conf.d/{domains,main},html,logs/domains,ssl}
```

### 3. Generate Diffie-Hellman Parameters (DHParam)

Generate custom 2048-bit Diffie-Hellman parameters and set strict owner-only permissions:

```bash
sudo openssl dhparam -out /home/angie/data/ssl/dhparam.pem 2048
sudo chown angie:angie /home/angie/data/ssl/dhparam.pem
sudo chmod 400 /home/angie/data/ssl/dhparam.pem
```

### 4. Download Configuration Files

Download the complete set of configuration files and conf.d snippets from the repository:

```bash
REPO="https://raw.githubusercontent.com/webstudiobond/angie-docker-compose/main"

sudo -u angie curl -fsSL ${REPO}/data/angie.conf -o /home/angie/data/angie.conf
sudo -u angie curl -fsSL ${REPO}/data/mime.types -o /home/angie/data/mime.types
sudo -u angie curl -fsSL ${REPO}/data/modules.conf -o /home/angie/data/modules.conf

sudo -u angie curl -fsSL ${REPO}/data/conf.d/0rtt-anti-replay.conf -o /home/angie/data/conf.d/0rtt-anti-replay.conf
sudo -u angie curl -fsSL ${REPO}/data/conf.d/error-pages.inc -o /home/angie/data/conf.d/error-pages.inc
sudo -u angie curl -fsSL ${REPO}/data/conf.d/healthcheck.inc -o /home/angie/data/conf.d/healthcheck.inc
sudo -u angie curl -fsSL ${REPO}/data/conf.d/http-protocols.conf -o /home/angie/data/conf.d/http-protocols.conf
sudo -u angie curl -fsSL ${REPO}/data/conf.d/security-headers.inc -o /home/angie/data/conf.d/security-headers.inc
```

### 5. Download Compose Manifest and Environment Config

```bash
sudo -u angie curl -fsSL ${REPO}/docker-compose.yaml -o /home/angie/docker-compose.yaml
sudo -u angie curl -fsSL ${REPO}/.env.example -o /home/angie/.env
```

### 6. Configure Environment

Open `/home/angie/.env` and ensure `APP_UID` and `APP_GID` match the values defined in Step 1:

```bash
sudo -u angie nano /home/angie/.env
sudo chmod 600  /home/angie/.env
```

### 7. Cloudflare IP Automation

Automate periodic fetching of the latest official Cloudflare IPv4 and IPv6 CIDR ranges to ensure `CF-Connecting-IP` restoration remains accurate.

Download the update script and install it with execution permissions:

```bash
REPO="https://raw.githubusercontent.com/webstudiobond/angie-docker-compose/main"

sudo curl -fsSL ${REPO}/usr/local/bin/update-cf-ips.sh -o /usr/local/bin/update-cf-ips.sh
sudo chmod 500 /usr/local/bin/update-cf-ips.sh
```

Execute the script to verify IP download, syntax checking, and Angie container reloading:

```bash
sudo /usr/local/bin/update-cf-ips.sh
```

Install and activate the weekly automated cron job:

```bash
sudo curl -fsSL ${REPO}/etc/cron.d/update-cf-ips -o /etc/cron.d/update-cf-ips
sudo chmod 400 /etc/cron.d/update-cf-ips
```

### 8. Start the Stack

Pull images and start the container:

```bash
sudo docker compose -f /home/angie/docker-compose.yaml pull
sudo docker compose -f /home/angie/docker-compose.yaml up -d
```

To view real-time container logs:

```bash
sudo docker compose -f /home/angie/docker-compose.yaml logs -f angie
```

To stop the container:

```bash
sudo docker compose -f /home/angie/docker-compose.yaml stop
```

To stop and remove container and networks:

```bash
sudo docker compose -f /home/angie/docker-compose.yaml down
```

</details>

---

<details>
<summary><strong>Log Rotation &amp; Systemd Timer</strong></summary>

Install `logrotate` on the host:

```bash
sudo apt update && sudo apt install -y logrotate
```

Download the Angie logrotate configuration:

```bash
REPO="https://raw.githubusercontent.com/webstudiobond/angie-docker-compose/main"

sudo curl -fsSL ${REPO}/etc/logrotate.d/angie -o /etc/logrotate.d/angie
```

Verify the logrotate configuration syntax in debug mode:

```bash
sudo logrotate -d /etc/logrotate.d/angie
```

Adjust the systemd logrotate timer to execute daily at 03:00:

```bash
sudo systemctl edit logrotate.timer
```

```toml
[Timer]
OnCalendar=
OnCalendar=*-*-* 03:00:00
```

Reload systemd daemon and restart the timer:

```bash
sudo systemctl daemon-reload
sudo systemctl restart logrotate.timer
```

</details>

---

<details>
<summary><strong>Edge Proxy Administration &amp; CLI Helper</strong></summary>

#### Method 1: System Wrapper

Install the Angie container CLI wrapper script to `/usr/local/bin/angie` and set execution permissions:

```bash
REPO="https://raw.githubusercontent.com/webstudiobond/angie-docker-compose/main"

sudo curl -fsSL ${REPO}/usr/local/bin/angie -o /usr/local/bin/angie
sudo chmod 500 /usr/local/bin/angie
```

Test configuration syntax and reload Angie gracefully without dropping connections:

```bash
sudo angie -t && sudo angie -s reload
```

Useful management commands using the system wrapper:

```bash
sudo angie -V
sudo ls -la /home/angie/data/certs/
sudo tail -f /home/angie/data/logs/domains/wordpress.log
```

#### Method 2: Shell Function for Root

When operating directly as root, define a shell function in `~/.bashrc`:

```bash
nano ~/.bashrc
```

```bash
angie() {
    docker exec angie angie "$@"
}
```

Apply the changes to your current session:

```bash
source ~/.bashrc
```

Test configuration syntax and reload Angie gracefully without dropping connections:

```bash
angie -t && angie -s reload
```

Useful management commands when operating as root:

```bash
angie -V
ls -la /home/angie/data/certs/
tail -f /home/angie/data/logs/domains/wordpress.log
```

</details>

---

<details>
<summary><strong>Virtual Host Setup</strong></summary>

### Virtual Host Configuration

Virtual host configurations are created on demand as needed when deploying sites or services. Pre-configured templates are available in [`data/conf.d/domains/`](data/conf.d/domains/), each containing a self-documenting header with all required placeholders.

The guide below demonstrates deploying a WordPress virtual host as an example.

#### WordPress Integration ([wordpress-docker](https://github.com/webstudiobond/wordpress-docker))

Download the WordPress virtual host template directly to your site configuration file:

```bash
REPO="https://raw.githubusercontent.com/webstudiobond/angie-docker-compose/main"

SITE_USER="mywpsite"
sudo -u angie curl -fsSL ${REPO}/data/conf.d/domains/wordpress.conf \
  -o /home/angie/data/conf.d/domains/${SITE_USER}.conf
```

Substitute the placeholders inside the configuration file so upstream requests route to `${SITE_USER}_angie:80` on the `frontend_gateway` network:

```bash
DOMAIN="example.com"

sudo -u angie sed -i \
  -e "s|wordpress\.example|${DOMAIN}|g" \
  -e "s|mysite|${SITE_USER}|g" \
  /home/angie/data/conf.d/domains/${SITE_USER}.conf
```

Review and customize the configuration as needed (e.g., adjust `server_name` or conditional access logging rules):

```bash
sudo -u angie nano /home/angie/data/conf.d/domains/${SITE_USER}.conf
```

#### Verification & DNS Cutover

1. Test Angie configuration syntax:

```bash
sudo angie -t
```

2. Point your domain's public DNS A/AAAA records to the server IP.

3. Once DNS propagates, reload Angie to apply changes and issue the TLS certificate:

```bash
sudo angie -s reload
```

4. Verify live HTTPS response and TLS handshake:

```bash
curl -I https://example.com
```

</details>

---

<details>
<summary><strong>Development & Testing</strong></summary>

## Development & Testing

For local development and testing guidelines, refer to [DEVELOPMENT](DEVELOPMENT.md).

</details>

---

<details>
<summary><strong>License & Attribution</strong></summary>

## License & Attribution

This repository and deployment architecture are licensed under the [MIT License](LICENSE).
This project is an independent containerized deployment architecture and is not affiliated with, endorsed, or sponsored by Angie.

**Angie License & Attribution:** All rights to [Angie](https://en.angie.software/) belong to its respective authors and copyright holders. For terms of distribution and use, refer to the official [Angie License](https://en.angie.software/angie/license-angie/).
</details>
