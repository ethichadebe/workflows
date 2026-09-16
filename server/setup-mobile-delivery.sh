#!/usr/bin/env bash
# Mobile Delivery: one-time server setup.
#
# Run as root. Expects three files already copied to /tmp:
#   /tmp/md-deploy  /tmp/md-deploy-root  /tmp/md_deploy.pub
#
# What it does:
#   1. creates the deploy account, whose SSH key can only run the dispatcher
#   2. installs the dispatcher, with one narrow sudo rule for its root half
#   3. adds a localhost-only nginx vhost used to check a Candidate site
#   4. stops the askus API being published to the internet (nginx still fronts it)
#   5. gives the API and database memory limits so neither can starve the box
#   6. adds 2 GB of swap
#   7. turns on a firewall allowing only SSH, HTTP, HTTPS and Hostinger's console
set -euo pipefail

say() { printf '\n=== %s\n' "$*"; }

for f in /tmp/md-deploy /tmp/md-deploy-root /tmp/md_deploy.pub; do
  [ -f "$f" ] || { echo "missing $f - copy it up first" >&2; exit 1; }
done

say "1. deploy account"
if id deploy >/dev/null 2>&1; then
  echo "  already exists"
else
  useradd --create-home --shell /bin/bash deploy
  passwd --lock deploy >/dev/null
  echo "  created (password login locked)"
fi

say "2. dispatcher and sudo rule"
install -o root -g root -m 0755 /tmp/md-deploy      /usr/local/bin/md-deploy
install -o root -g root -m 0755 /tmp/md-deploy-root /usr/local/sbin/md-deploy-root
printf 'deploy ALL=(root) NOPASSWD: /usr/local/sbin/md-deploy-root\n' > /etc/sudoers.d/md-deploy
chmod 0440 /etc/sudoers.d/md-deploy
visudo -c -q && echo "  sudo rule valid"

install -d -o deploy -g deploy -m 0700 /home/deploy/.ssh
{
  printf 'restrict,command="/usr/local/bin/md-deploy" '
  cat /tmp/md_deploy.pub
} > /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 0600 /home/deploy/.ssh/authorized_keys
echo "  deploy key installed, locked to the dispatcher"

say "3. candidate vhost (localhost only, serves dist.new)"
cat > /etc/nginx/conf.d/md-candidate.conf <<'NGINX'
# Used by Mobile Delivery to check a Candidate site before Cutover.
# Reachable only from the server itself.
server {
    listen 127.0.0.1:8090;
    server_name _;
    root /opt/askus-frontend/frontend/dist.new;
    index index.html;
    location / { try_files $uri $uri/ /index.html; }
}
NGINX
nginx -t && systemctl reload nginx && echo "  nginx reloaded"

say "4. stop publishing the API to the internet"
compose=/opt/askus/backend/api/docker-compose.yml
if grep -q '"8080:8080"' "$compose"; then
  cp "$compose" "${compose}.bak.$(date -u +%Y%m%d%H%M%S)"
  sed -i 's/"8080:8080"/"127.0.0.1:8080:8080"/' "$compose"
  echo "  compose updated (backup kept)"
else
  echo "  already bound to localhost or changed by hand - leaving alone"
fi

say "5. memory limits for the API and database"
python3 - "$compose" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
for name, limit in (("askus-api", "1g"), ("askus-db", "1g")):
    if f"container_name: {name}" in s and f"mem_limit" not in s.split(f"container_name: {name}")[1][:200]:
        s = s.replace(f"container_name: {name}", f"container_name: {name}\n    mem_limit: {limit}")
open(p, "w").write(s)
print("  limits set where missing")
PY

cd /opt/askus/backend/api && docker compose up -d >/dev/null && echo "  containers recreated with the new settings"

say "6. swap"
if swapon --show | grep -q .; then
  echo "  swap already present"
else
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || printf '/swapfile none swap sw 0 0\n' >> /etc/fstab
  sysctl -q vm.swappiness=10
  grep -q '^vm.swappiness' /etc/sysctl.conf || printf 'vm.swappiness=10\n' >> /etc/sysctl.conf
  echo "  2 GB swap added"
fi

say "7. firewall"
command -v ufw >/dev/null || { apt-get update -qq && apt-get install -y -qq ufw; }
ufw allow 22/tcp    >/dev/null
ufw allow 80/tcp    >/dev/null
ufw allow 443/tcp   >/dev/null
ufw allow from 169.254.0.0/16 >/dev/null   # Hostinger's web console
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw --force enable >/dev/null
echo "  firewall on"

say "RESULT"
echo "  deploy key test:      run from your laptop:  ssh -i ~/.ssh/md_deploy deploy@SERVER 'status askus'"
echo "  api published on:     $(ss -ltnH | awk '$4 ~ /:8080$/ {print $4}' | tr '\n' ' ')"
echo "  swap:                 $(free -h | awk '/Swap/ {print $2}')"
echo "  firewall:             $(ufw status | head -1)"
echo "  api through nginx:    $(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://127.0.0.1:8080/api/provinces)"
echo "  site through nginx:   $(curl -s -o /dev/null -w '%{http_code}' --max-time 10 --resolve askusapp.ethichadebe.me:443:127.0.0.1 -k https://askusapp.ethichadebe.me/)"
