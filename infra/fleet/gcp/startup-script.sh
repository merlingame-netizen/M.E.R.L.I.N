#!/usr/bin/env bash
# GCP e2-micro (1 GB) base provisioning — lightweight VPS for SQLite services / cron.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl wget sqlite3 python3 python3-venv python3-pip tmux htop jq ufw
# 2 GB swap (1 GB RAM is tight)
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
ufw allow OpenSSH || true
ufw --force enable || true
mkdir -p /opt/merlin && echo "merlin gcp e2-micro ready ($(date -u))" > /opt/merlin/READY
