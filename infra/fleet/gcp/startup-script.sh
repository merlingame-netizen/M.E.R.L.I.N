#!/usr/bin/env bash
# GCP e2-micro (1 GB) — lightweight VPS + Uptime Kuma monitoring dashboard.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl wget sqlite3 python3 python3-venv python3-pip tmux htop jq ufw ca-certificates
# 2 GB swap (1 GB RAM is tight)
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
# Docker
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker
# Uptime Kuma — monitoring dashboard. Bound to 127.0.0.1 only (access via SSH tunnel).
docker run -d --name uptime-kuma --restart unless-stopped \
  -p 127.0.0.1:3001:3001 -v uptime-kuma:/app/data louislam/uptime-kuma:1
# Firewall: only SSH; 3001 stays private (loopback + no GCP firewall rule).
ufw allow OpenSSH || true
ufw --force enable || true
mkdir -p /opt/merlin && echo "merlin gcp e2-micro + uptime-kuma ready ($(date -u))" > /opt/merlin/READY
