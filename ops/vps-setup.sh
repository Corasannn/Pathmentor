#!/usr/bin/env bash
# PathMentor — One-shot VPS setup for CubePath (Ubuntu 22.04/24.04)
# Usage: bash ops/vps-setup.sh
# Run as root on a fresh VPS.
set -euo pipefail

APP_DIR="/var/www/pathmentor"
DOMAIN="${1:-}"  # Optional: pass domain as arg (e.g., bash vps-setup.sh pathmentor.com)

echo "=== PathMentor VPS Setup ==="
echo "App dir: $APP_DIR"
[ -n "$DOMAIN" ] && echo "Domain: $DOMAIN" || echo "Domain: (not set — will use IP only)"

# ── 1. System updates ──────────────────────────────────────────────
echo "[1/7] Updating system packages..."
apt-get update -y
apt-get upgrade -y

# ── 2. Node.js 20 (via NodeSource) ─────────────────────────────────
echo "[2/7] Installing Node.js 20..."
if ! command -v node &>/dev/null || [[ "$(node -v)" != v20* ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
echo "Node: $(node -v) | npm: $(npm -v)"

# ── 3. Nginx ───────────────────────────────────────────────────────
echo "[3/7] Installing nginx..."
apt-get install -y nginx

# ── 4. Firewall (UFW) ─────────────────────────────────────────────
echo "[4/7] Configuring firewall..."
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
echo "Firewall enabled: SSH + HTTP + HTTPS"

# ── 5. App directory + git clone ───────────────────────────────────
echo "[5/7] Setting up app directory..."
mkdir -p "$APP_DIR"
if [ ! -d "$APP_DIR/.git" ]; then
  git clone https://github.com/Rodcolca/pathmentor.git "$APP_DIR"
else
  echo "Repo already cloned, pulling latest..."
  cd "$APP_DIR" && git pull
fi

# ── 6. Nginx config ───────────────────────────────────────────────
echo "[6/7] Configuring nginx..."

NGINX_CONF="/etc/nginx/sites-available/pathmentor"
cat > "$NGINX_CONF" <<NGINX
server {
    listen 80;
    server_name ${DOMAIN:-_};

    # Static frontend
    root $APP_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Health check (proxied to Express)
    location = /api/health {
        proxy_pass http://127.0.0.1:8080/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # API proxy to Express (SSE-friendly)
    location /api/ {
        proxy_pass http://127.0.0.1:8080/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Connection "";
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    access_log /var/log/nginx/pathmentor.access.log;
    error_log  /var/log/nginx/pathmentor.error.log;
}
NGINX

# Enable site, remove default
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/pathmentor
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl reload nginx
echo "Nginx configured and reloaded"

# ── 7. Prepare for first deploy ────────────────────────────────────
echo "[7/7] Creating deploy user and directories..."

# Create www-data ownership
chown -R www-data:www-data "$APP_DIR"

# Ensure .env.local placeholder
if [ ! -f "$APP_DIR/.env.local" ]; then
  cat > "$APP_DIR/.env.local" <<ENVFILE
NODE_ENV=production
PORT=8080
OPENROUTER_API_KEY=YOUR_KEY_HERE
OPENROUTER_MODEL=openrouter/free
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
ALLOWED_ORIGINS=
LOG_LEVEL=info
ENVFILE
  chown www-data:www-data "$APP_DIR/.env.local"
  chmod 600 "$APP_DIR/.env.local"
  echo ""
  echo "⚠️  IMPORTANT: Edit $APP_DIR/.env.local with your real API key!"
  echo ""
fi

# Generate SSH key for GitHub Actions (if not exists)
DEPLOY_KEY="/root/.ssh/pathmentor_deploy"
if [ ! -f "$DEPLOY_KEY" ]; then
  ssh-keygen -t ed25519 -f "$DEPLOY_KEY" -N "" -C "pathmentor-deploy"
  echo ""
  echo "=== SSH Public Key for GitHub Secrets ==="
  echo "Add this as SSH_KEY secret (the private key):"
  echo ""
  cat "$DEPLOY_KEY"
  echo ""
  echo "=== Also add to ~/.ssh/authorized_keys ==="
  cat "${DEPLOY_KEY}.pub" >> /root/.ssh/authorized_keys
  echo ""
fi

echo ""
echo "========================================="
echo "  ✅ VPS Setup Complete!"
echo "========================================="
echo ""
echo "NEXT STEPS:"
echo "1. Edit .env.local with your API key:"
echo "   nano $APP_DIR/.env.local"
echo ""
echo "2. Add GitHub Secrets (Settings → Secrets → Actions):"
echo "   - VPS_HOST: $(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
echo "   - VPS_USER: root"
echo "   - VPS_PATH: $APP_DIR"
echo "   - SSH_KEY:  (content of $DEPLOY_KEY)"
echo ""
echo "3. Trigger deploy: gh workflow run deploy.yml"
echo "4. Health check: curl http://localhost/api/health"
echo ""
echo "If you have a domain, run: certbot --nginx -d yourdomain.com"
echo "========================================="
