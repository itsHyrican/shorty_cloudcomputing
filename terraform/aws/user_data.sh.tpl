#!/usr/bin/env bash
# Deployed by Terraform as cloud-init user_data: installs Docker, clones the
# repository, builds both images and starts the Shorty stack.
# Full log: /var/log/shorty-deploy.log
set -euxo pipefail

exec > /var/log/shorty-deploy.log 2>&1
echo "=== Shorty deployment started: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

# --- Swap: the dotnet/npm image builds need more RAM than a small instance has
if ! swapon --show | grep -q '^/swapfile'; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- Tooling
dnf install -y docker git
systemctl enable --now docker

# --- Source code
REPO_DIR="/opt/shorty"
rm -rf $${REPO_DIR}
git clone --depth 1 --branch ${repo_branch} ${repo_clone_url} $${REPO_DIR}

# --- Build images
docker build \
  -f $${REPO_DIR}/shorty_backend/shorty_backend/Dockerfile \
  -t shorty-backend:local \
  $${REPO_DIR}/shorty_backend

docker build \
  --build-arg "API_URL=${api_url}" \
  -t shorty-frontend:local \
  $${REPO_DIR}/shorty_frontend

# --- Wait until the database accepts connections (RDS takes a few minutes)
until bash -c "exec 3<>/dev/tcp/${db_host}/${db_port}" 2>/dev/null; do
  echo "Waiting for database ${db_host}:${db_port} ..."
  sleep 5
done

# --- Start containers
docker rm -f shorty-backend shorty-frontend >/dev/null 2>&1 || true

docker run -d --name shorty-backend --restart unless-stopped \
  -e "ASPNETCORE_URLS=http://+:8080" \
  -e "ConnectionStrings__DefaultConnection=Host=${db_host};Port=${db_port};Database=${db_name};Username=${db_user};Password=${db_password}" \
  -e "ShortUrlOptions__DefaultTtlHours=${default_ttl_hours}" \
  -e "ShortUrlOptions__MaxTtlHours=${max_ttl_hours}" \
  -e "ShortUrlOptions__CleanupIntervalMinutes=${cleanup_interval_minutes}" \
  -p 8080:8080 \
  shorty-backend:local

docker run -d --name shorty-frontend --restart unless-stopped \
  -e "PORT=80" \
  -e "NG_ALLOWED_HOSTS=${app_public_ip},${frontend_allowed_hosts}" \
  -p 80:4000 \
  shorty-frontend:local

echo "=== Shorty deployment finished: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
