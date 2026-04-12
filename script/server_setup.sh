#!/usr/bin/env bash
# =============================================================================
# BarberApp — Hetzner VPS initial setup
# Run this ONCE on a fresh Hetzner Ubuntu 22.04/24.04 server as root.
#
# What it does:
#   1. Creates a non-root 'deploy' user (Kamal uses this)
#   2. Installs Docker
#   3. Installs Nginx
#   4. Installs Certbot with the Hetzner DNS plugin
#   5. Obtains wildcard Let's Encrypt certificates:
#        *.barberapp.club          (production)
#        *.staging.barberapp.club  (staging)
#   6. Installs both Nginx site configs from this repo
#   7. Production app:  proxied from localhost:3000
#      Staging app:     proxied from localhost:3001
#
# Usage:
#   scp script/server_setup.sh root@SERVER_IP:/root/
#   scp config/nginx/barberapp.conf root@SERVER_IP:/root/
#   scp config/nginx/barberapp-staging.conf root@SERVER_IP:/root/
#   ssh root@SERVER_IP "bash /root/server_setup.sh"
#
# After this script:
#   1. Export your secrets (see .kamal/secrets and .kamal/secrets.staging)
#   2. Run: kamal setup -d staging   # deploy staging
#   3. Run: kamal proxy stop -d staging
#   4. Run: kamal setup              # deploy production
#   5. Run: kamal proxy stop
# =============================================================================
set -euo pipefail

PROD_DOMAIN="barberapp.club"
STAGING_DOMAIN="staging.barberapp.club"
DEPLOY_USER="deploy"
HETZNER_API_TOKEN=""            # ← set this before running

if [[ -z "$HETZNER_API_TOKEN" ]]; then
  echo "ERROR: Set HETZNER_API_TOKEN at the top of this script before running."
  exit 1
fi

echo "==> Creating deploy user"
if ! id "$DEPLOY_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
  usermod -aG sudo "$DEPLOY_USER"
  # Copy root's authorised keys so Kamal can SSH in
  mkdir -p /home/"$DEPLOY_USER"/.ssh
  cp /root/.ssh/authorized_keys /home/"$DEPLOY_USER"/.ssh/authorized_keys
  chown -R "$DEPLOY_USER":"$DEPLOY_USER" /home/"$DEPLOY_USER"/.ssh
  chmod 700 /home/"$DEPLOY_USER"/.ssh
  chmod 600 /home/"$DEPLOY_USER"/.ssh/authorized_keys
  # Passwordless sudo for docker (Kamal needs it)
  echo "$DEPLOY_USER ALL=(ALL) NOPASSWD: /usr/bin/docker" >> /etc/sudoers.d/deploy
fi

echo "==> Installing Docker"
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
usermod -aG docker "$DEPLOY_USER"
systemctl enable --now docker

echo "==> Installing Nginx"
apt-get install -y -qq nginx
systemctl enable nginx

echo "==> Installing Certbot + Hetzner DNS plugin"
apt-get install -y -qq python3-pip
pip3 install certbot certbot-dns-hetzner --quiet

echo "==> Writing Hetzner DNS credentials for Certbot"
mkdir -p /etc/letsencrypt
cat > /etc/letsencrypt/hetzner.ini <<EOF
dns_hetzner_api_token = ${HETZNER_API_TOKEN}
EOF
chmod 600 /etc/letsencrypt/hetzner.ini

echo "==> Obtaining wildcard certificate for production (*.${PROD_DOMAIN})"
certbot certonly \
  --dns-hetzner \
  --dns-hetzner-credentials /etc/letsencrypt/hetzner.ini \
  --non-interactive \
  --agree-tos \
  --email "admin@${PROD_DOMAIN}" \
  -d "${PROD_DOMAIN}" \
  -d "*.${PROD_DOMAIN}"

echo "==> Obtaining wildcard certificate for staging (*.${STAGING_DOMAIN})"
certbot certonly \
  --dns-hetzner \
  --dns-hetzner-credentials /etc/letsencrypt/hetzner.ini \
  --non-interactive \
  --agree-tos \
  --email "admin@${PROD_DOMAIN}" \
  -d "${STAGING_DOMAIN}" \
  -d "*.${STAGING_DOMAIN}"

echo "==> Installing Nginx site configs"
cp /root/barberapp.conf /etc/nginx/sites-available/barberapp
ln -sf /etc/nginx/sites-available/barberapp /etc/nginx/sites-enabled/barberapp

cp /root/barberapp-staging.conf /etc/nginx/sites-available/barberapp-staging
ln -sf /etc/nginx/sites-available/barberapp-staging /etc/nginx/sites-enabled/barberapp-staging

rm -f /etc/nginx/sites-enabled/default

# Create certbot webroot for HTTP-01 renewal fallback
mkdir -p /var/www/certbot

nginx -t
systemctl reload nginx

echo "==> Setting up automatic cert renewal (twice daily)"
(crontab -l 2>/dev/null; echo "0 3,15 * * * certbot renew --quiet && systemctl reload nginx") | crontab -

echo ""
echo "==> Server setup complete!"
echo ""
echo "Next steps:"
echo "  1. Fill in your secrets (see .kamal/secrets and .kamal/secrets.staging)"
echo "  2. From your dev machine: kamal setup -d staging"
echo "  3. From your dev machine: kamal proxy stop -d staging"
echo "  4. From your dev machine: kamal setup"
echo "  5. From your dev machine: kamal proxy stop"
echo "  6. Verify: https://${PROD_DOMAIN} and https://demo.${PROD_DOMAIN}"
echo "             https://${STAGING_DOMAIN} and https://demo.${STAGING_DOMAIN}"
