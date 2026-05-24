#!/bin/bash
set -e

# ============================================================
# Dart Pro App — Server Setup Script
# Usage: curl -fsSL https://raw.githubusercontent.com/tarabaneugene-maker/dart-pro-app/main/server/setup.sh | bash
# ============================================================

echo "============================================"
echo " Dart Pro App — Server Setup"
echo "============================================"

# --- 1. Add SSH key for remote access ---
echo "[1/6] Adding SSH key..."
mkdir -p ~/.ssh
cat >> ~/.ssh/authorized_keys << 'SSHKEY'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFt/wpYeMvYbRU0PekpCta4zJCaJBZGRD/f0jV9wY5ujwn1tx20b0i1eZQFzsWAV+tPh+1CHk7CgNoDnnpfMIPrtZtBzVthMl20CF/XtE/ckaUc8bEUcTaURDFZfLdTj+weSjwT7Yn2+NhqwX0xuptUq91/xFDZIWcD1bTriFvqTlqkCc8Jfn4ogLlf/SsNnSEDokzsPt0+LN8nPXwsrAu2w9T5xiiAsplboQCNP41ULxFiEcIbauyQ3KNw1vSRbeuNyufISm79KR346L+EVpK9gmG89oVx3fpa4212dlmNpYX2X0WSAcA35wBt/7SKGnJylNg48r7DpONsi6Kuy6/DhxfyDh+Ih+AXGbs1ZXoFpriRCA1/+aRXhsJOW7bg71o33u76X1xI9zsbAgZrAOOGn1+a0ecE7faQ7evZitPAEuemjx8+VzUHyx5BNXE+sI/PmlzMQAOyjsFGO2iabUBUN3pCwFKvSdReXExdRnY3kChSD7bHRAhhArSsjx6t9ZvnZrpluQLvNFnsIW8N4iqxC6QWqwNNMjdIQDju1Gl+ItPgq7gVwcsW0GLNm4g3iDGq5nLHYjua1+OyNCNaOJAYs7VutxN9n0aNcfMEspJYqKFXvYaUy/VSbTtbTSBZlt9wR4XdhrYCieS2YxoI+InK0b99yOIHiODIH5zHXpJzQ== cloudru-dart-pro
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKMgQNlvwUePjtigSOU8CrNyPZoD5lgkuZvtCpBOWhRP Пользователь@DESKTOP-K5F9V9E
SSHKEY
chmod 600 ~/.ssh/authorized_keys
echo "  OK"

# --- 2. Install Docker ---
echo "[2/6] Installing Docker..."
if ! command -v docker &> /dev/null; then
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    echo "  Docker installed"
else
    echo "  Docker already installed"
fi

# --- 3. Install Caddy ---
echo "[3/6] Installing Caddy..."
if ! command -v caddy &> /dev/null; then
    apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -qq
    apt-get install -y -qq caddy
    echo "  Caddy installed"
else
    echo "  Caddy already installed"
fi

# --- 4. Clone / update project ---
echo "[4/6] Cloning project..."
if [ -d /opt/dart-pro-app ]; then
    cd /opt/dart-pro-app && git pull
else
    git clone https://github.com/tarabaneugene-maker/dart-pro-app.git /opt/dart-pro-app
fi
cd /opt/dart-pro-app

# --- 5. Build and start Docker container ---
echo "[5/6] Building and starting server..."
cd /opt/dart-pro-app/server

# Create data directory for persistent DB
mkdir -p /opt/dart-pro-data

# Stop old container if exists
docker compose down 2>/dev/null || true
docker rm -f dart-pro-server 2>/dev/null || true

# Build and run
docker build -t dart-pro-server .
docker run -d \
    --name dart-pro-server \
    --restart unless-stopped \
    -p 127.0.0.1:8080:8080 \
    -v /opt/dart-pro-data:/app/data \
    -e PORT=8080 \
    -e JWT_SECRET="$(openssl rand -hex 32)" \
    dart-pro-server

echo "  Server started on port 8080"

# --- 6. Configure Caddy reverse proxy ---
echo "[6/6] Configuring Caddy..."
cat > /etc/caddy/Caddyfile << 'CADDY'
176.109.111.87.nip.io {
    reverse_proxy localhost:8080
}
CADDY

systemctl enable caddy 2>/dev/null || true
systemctl restart caddy

echo ""
echo "============================================"
echo " Setup complete!"
echo " Server: http://176.109.111.87.nip.io"
echo "============================================"
