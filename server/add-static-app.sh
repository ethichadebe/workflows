#!/usr/bin/env bash
# Mobile Delivery: prepare the server for one static app, before its first deploy.
#
#   bash add-static-app.sh <app> <domain> <candidate-port> <dir> [spa]
#   bash add-static-app.sh portfolio www.ethichadebe.com 8091 /opt/portfolio
#   bash add-static-app.sh portfolio www.ethichadebe.com 8091 /opt/portfolio spa
#
# Pass `spa` for a single-page app whose routes are handled in the browser —
# React Router, Vue Router and the like. Without it a URL with no matching file
# gets a real 404, which is what a multi-page site wants. With it, those URLs
# serve index.html so the app can route them itself. Getting this wrong is
# visible immediately: every route but "/" 404s on a refresh.
#
# Run as root. Safe to re-run: it changes nothing that is already correct.
#
# This exists because the alternative is typing two nginx vhosts by hand on a
# box that is already serving other people's sites, and a typo there is an
# outage. ADR-0007 keeps the dispatcher out of this on purpose — a leaked
# deploy key must not be able to author nginx config. A person running a
# script is still the person doing it, same as setup-mobile-delivery.sh.
#
# What it does, for the app you name:
#   1. creates the app's directory
#   2. a localhost-only vhost serving dist.new, for checking a new version
#   3. the live vhost, with a self-signed certificate if none exists yet
#   4. validates the config and reloads nginx
set -euo pipefail

die() { echo "refused: $*" >&2; exit 2; }

[ "$(id -u)" = "0" ] || die "run this as root"
case "$#" in 4|5) ;; *) die "usage: $0 <app> <domain> <candidate-port> <dir> [spa]" ;; esac

app="$1"; domain="$2"; port="$3"; dir="$4"; mode="${5:-mpa}"
case "$mode" in spa|mpa) ;; *) die "fifth argument must be 'spa' or omitted, not '$mode'" ;; esac

# Only the live vhost differs. The candidate vhost is always =404: the cutover
# check fetches the page and the first script it references, and a fallback
# answers a missing script with index.html and a 200, so a build that lost its
# assets would pass the check and go live broken.
if [ "$mode" = "spa" ]; then
  LIVE_FALLBACK='/index.html'
  LIVE_NOTE='# Single-page app: unmatched URLs serve index.html so the browser can route them.'
else
  LIVE_FALLBACK='=404'
  LIVE_NOTE='# Multi-page site: an unmatched URL gets a real 404. For a single-page app with
    # client-side routes, re-run this script with `spa` as the fifth argument.'
fi

# Same rule the dispatcher applies: plain lowercase, no paths, no shell characters.
case "$app" in "" | *[!a-z0-9-]*) die "app name '$app' must be plain lowercase" ;; esac
case "$domain" in "" | *[!a-zA-Z0-9.-]*) die "domain '$domain' is not a hostname" ;; esac
case "$port" in "" | *[!0-9]*) die "port '$port' is not a number" ;; esac
[ "$port" -ge 1024 ] && [ "$port" -le 65535 ] || die "port $port is outside 1024-65535"
case "$dir" in /*) ;; *) die "dir '$dir' must be an absolute path" ;; esac

DISPATCHER=/usr/local/sbin/md-deploy-root
CONFD=/etc/nginx/conf.d
CANDIDATE_CONF="${CONFD}/md-candidate-${app}.conf"
LIVE_CONF="${CONFD}/md-site-${app}.conf"
CRT="/etc/ssl/certs/md-${app}-selfsigned.crt"
KEY="/etc/ssl/private/md-${app}-selfsigned.key"

say() { printf '\n=== %s\n' "$*"; }

# ── Guards ────────────────────────────────────────────────────────────────────
# An app the dispatcher does not know cannot deploy, so setting up nginx for it
# would leave a site served from a folder nothing ever writes to.
[ -f "$DISPATCHER" ] || die "$DISPATCHER is missing — install the dispatcher first"
grep -qE "^  ${app}\)" "$DISPATCHER" ||
  die "the dispatcher has no '${app})' block. Update it from the workflows repo first."

# A candidate port shared between two apps means one app's new version gets
# checked against the other app's folder, passes, and goes live unexamined.
if nginx -T 2>/dev/null | grep -qE "listen[[:space:]]+127\.0\.0\.1:${port}\b" &&
   ! grep -qs "127.0.0.1:${port}" "$CANDIDATE_CONF"; then
  die "port ${port} is already used by another vhost — pick one nothing else has"
fi

say "1. the app's directory"
install -d -o deploy -g deploy -m 0755 "$dir"
echo "  $dir"

say "2. candidate vhost (localhost only, serves ${dir}/dist.new)"
# `=404` rather than a fallback to /index.html, deliberately. The cutover check
# fetches the page AND the first script the page references; with a fallback,
# a missing script is answered with index.html and a 200, so a build that lost
# its assets passes the check and goes live broken. This vhost only ever serves
# those two requests, so it has no use for a fallback.
cat > "$CANDIDATE_CONF" <<NGINX
# Mobile Delivery: checks ${app}'s new version before it replaces the live one.
# Reachable only from this server. Written by add-static-app.sh.
server {
    listen 127.0.0.1:${port};
    server_name _;
    root ${dir}/dist.new;
    index index.html;
    # Never fall back here: a missing asset must answer 404 so the check sees it.
    location / { try_files \$uri \$uri/ =404; }
}
NGINX
echo "  $CANDIDATE_CONF on 127.0.0.1:${port}"

say "3. certificate"
if [ -f "$CRT" ] && [ -f "$KEY" ]; then
  echo "  self-signed certificate already present, left alone"
elif nginx -T 2>/dev/null | grep -q "ssl_certificate.*${domain}"; then
  echo "  a certificate for ${domain} is already configured elsewhere, left alone"
else
  # The deploy's own check uses curl -k, so this is enough to prove the whole
  # path works while DNS still points somewhere else. Replace it with certbot
  # once the domain resolves here.
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$KEY" -out "$CRT" -subj "/CN=${domain}" 2>/dev/null
  chmod 0600 "$KEY"
  echo "  self-signed certificate created for ${domain} (replace with certbot after DNS moves)"
fi

say "4. live vhost (${mode})"
if [ -f "$LIVE_CONF" ]; then
  echo "  $LIVE_CONF already exists, left alone"
  echo "  (delete it and re-run if you need it regenerated — spa/mpa, say)"
else
  cat > "$LIVE_CONF" <<NGINX
# Mobile Delivery: ${app}'s live site. Written by add-static-app.sh.
# The certificate below is self-signed until DNS points here; the deploy check
# uses curl -k so it passes either way. Replace with certbot afterwards.
server {
    listen 443 ssl;
    server_name ${domain};

    ssl_certificate     ${CRT};
    ssl_certificate_key ${KEY};

    root ${dir}/dist;
    index index.html;
    ${LIVE_NOTE}
    location / { try_files \$uri \$uri/ ${LIVE_FALLBACK}; }
}
NGINX
  echo "  $LIVE_CONF for ${domain}"
fi

say "5. validate and reload"
nginx -t
systemctl reload nginx
echo "  nginx reloaded"

say "RESULT"
# Not an ssh command: the private deploy key lives in the repo's secrets and on
# a laptop, never on this server, so `ssh -i ~/.ssh/md_deploy` here fails on a
# key that is not there.
echo "  Check it from this server, without deploying anything:"
echo "    /usr/local/sbin/md-deploy-root status ${app}"
echo
echo "  Or exercise the same locked path a real deploy takes, sudo rule included:"
echo "    sudo -u deploy SSH_ORIGINAL_COMMAND='status ${app}' /usr/local/bin/md-deploy"
echo
echo "  Two 404s is the correct answer before the first deploy: nginx is"
echo "  answering, but ${dir}/dist and dist.new do not exist yet. A 000 means"
echo "  nginx is not listening where it should be."
