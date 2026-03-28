#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_DIR"

if command -v npm >/dev/null 2>&1; then
  echo "[post-deploy] Installing backend deps..."
  (cd server && npm ci && npm run build)
else
  echo "[post-deploy] npm not found. Please install Node.js 20+" >&2
  exit 1
fi

if command -v systemctl >/dev/null 2>&1; then
  echo "[post-deploy] Ensuring systemd unit is installed..."
  sudo install -m 0644 ops/pathmentor.service /etc/systemd/system/pathmentor.service
  sudo systemctl daemon-reload
  sudo systemctl enable pathmentor.service
  if [ ! -f /etc/systemd/system/pathmentor.service ]; then
    echo "[post-deploy] Failed to install /etc/systemd/system/pathmentor.service" >&2
    exit 1
  fi
  echo "[post-deploy] systemd unit present."
  echo "[post-deploy] Restarting pathmentor service..."
  sudo systemctl restart pathmentor.service
  sudo systemctl status pathmentor.service --no-pager || true
else
  echo "[post-deploy] systemctl not available; skipping service restart" >&2
fi
