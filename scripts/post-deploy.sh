#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_DIR"

# Fail-fast: env file must exist before any build
if [ ! -f "$REPO_DIR/.env.local" ]; then
  echo "[post-deploy] Missing required env file: $REPO_DIR/.env.local" >&2
  echo "[post-deploy] Create it on VPS before restarting systemd." >&2
  exit 1
fi

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

  # Wait for service to become active (max 15s)
  echo "[post-deploy] Waiting for service to become active..."
  for i in $(seq 1 15); do
    STATUS=$(systemctl is-active pathmentor.service 2>/dev/null || true)
    if [ "$STATUS" = "active" ]; then
      echo "[post-deploy] Service is active."
      break
    fi
    if [ "$STATUS" = "failed" ]; then
      echo "[post-deploy] Service entered failed state!" >&2
      sudo systemctl status pathmentor.service --no-pager || true
      exit 1
    fi
    sleep 1
  done

  FINAL_STATUS=$(systemctl is-active pathmentor.service 2>/dev/null || true)
  if [ "$FINAL_STATUS" != "active" ]; then
    echo "[post-deploy] Service did not become active (status: $FINAL_STATUS)" >&2
    sudo systemctl status pathmentor.service --no-pager || true
    exit 1
  fi

  sudo systemctl status pathmentor.service --no-pager || true
else
  echo "[post-deploy] systemctl not available; skipping service restart" >&2
fi
