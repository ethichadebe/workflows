#!/usr/bin/env bash
# Tests the parts of md-deploy-root that decide whether a deploy is safe.
#
#   bash server/md-deploy-root.test.sh
#
# Runs anywhere: no Docker, no server, no network. It pulls the real functions
# out of the dispatcher rather than copying them, so a change there that breaks
# one of these rules fails here.
set -uo pipefail

DISPATCHER="$(dirname "${BASH_SOURCE[0]}")/md-deploy-root"

# Load just the helper functions, not the action dispatch below them.
for fn in file_value set_file_value destructive_sql valid_image; do
  body=$(sed -n "/^${fn}() {/,/^}/p" "$DISPATCHER")
  [ -n "$body" ] || { echo "cannot find ${fn}() in ${DISPATCHER}"; exit 1; }
  eval "$body"
done

pass=0
fail=0
ok()   { pass=$((pass + 1)); }
bad()  { fail=$((fail + 1)); echo "  FAIL: $1"; }

check()   { if [ "$2" = "$3" ]; then ok; else bad "$1: expected '$3', got '$2'"; fi; }
accepts() { if valid_image "$1"; then ok; else bad "should accept $1"; fi; }
rejects() { if valid_image "$1"; then bad "should reject $1"; else ok; fi; }
flags()   { if printf '%s\n' "$1" | destructive_sql >/dev/null; then ok; else bad "should flag: $1"; fi; }
allows()  { if printf '%s\n' "$1" | destructive_sql >/dev/null; then bad "should allow: $1"; else ok; fi; }

echo "valid_image"
# valid_image reads this from its caller's scope; it is loaded above rather
# than defined here, so shellcheck cannot see the use.
# shellcheck disable=SC2034
REGISTRY_PREFIX=ghcr.io/ethichadebe/brittle-ai
D=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
accepts "ghcr.io/ethichadebe/brittle-ai/backend@sha256:$D"
accepts "ghcr.io/ethichadebe/brittle-ai@sha256:$D"
rejects "ghcr.io/ethichadebe/brittle-ai/backend:latest"        # a tag can be repointed after the check
rejects "ghcr.io/someone-else/evil/backend@sha256:$D"          # outside this app's namespace
rejects "ghcr.io/ethichadebe/brittle-ai-evil/backend@sha256:$D"
rejects "ghcr.io/ethichadebe/brittle-ai/backend@sha256:${D:0:40}"
rejects "ghcr.io/ethichadebe/brittle-ai/backend@sha256:${D:0:63}z"
rejects 'ghcr.io/ethichadebe/brittle-ai/b;rm -rf /@sha256:'"$D"
rejects ""

echo "destructive_sql"
flags  "ALTER TABLE lists DROP COLUMN name;"
flags  "DROP TABLE users;"
flags  'ALTER TABLE "Product" RENAME COLUMN price TO amount;'
flags  "ALTER TABLE items ALTER COLUMN qty SET NOT NULL;"
flags  "TRUNCATE TABLE sessions;"
flags  "DELETE FROM products WHERE id > 0;"
flags  "ALTER TABLE p ALTER COLUMN price TYPE numeric(10,2);"
flags  "alter table lists drop constraint lists_pkey;"          # case does not matter
allows "CREATE TABLE stores (id TEXT PRIMARY KEY);"
allows 'ALTER TABLE "Product" ADD COLUMN "imageUrl" TEXT;'
allows "CREATE INDEX idx_products_name ON products(name);"
allows "CREATE UNIQUE INDEX ON lists(slug);"
allows "-- add a nullable column for the new field"

echo "file_value / set_file_value"
env_file=$(mktemp)
cat > "$env_file" <<'ENV'
# a comment
POSTGRES_USER=accucery
CHECKERS_COOKIES=a=1; b=2; path=/; secure
FRONTEND_PORT=127.0.0.1:8082
QUOTED="with spaces"
ENV
check "reads a plain value"        "$(file_value "$env_file" POSTGRES_USER)" "accucery"
check "keeps semicolons and ="     "$(file_value "$env_file" CHECKERS_COOKIES)" 'a=1; b=2; path=/; secure'
check "strips surrounding quotes"  "$(file_value "$env_file" QUOTED)" "with spaces"
check "missing key is empty"       "$(file_value "$env_file" NOPE)" ""
check "comment is not a key"       "$(file_value "$env_file" '# a comment')" ""

set_file_value "$env_file" BACKEND_IMAGE "ghcr.io/x@sha256:$D"
set_file_value "$env_file" BACKEND_IMAGE "ghcr.io/y@sha256:$D"
check "replaces rather than appends" "$(grep -c '^BACKEND_IMAGE=' "$env_file")" "1"
check "keeps the new value"          "$(file_value "$env_file" BACKEND_IMAGE)" "ghcr.io/y@sha256:$D"
check "leaves the cookie alone"      "$(file_value "$env_file" CHECKERS_COOKIES)" 'a=1; b=2; path=/; secure'
check "leaves the port alone"        "$(file_value "$env_file" FRONTEND_PORT)" "127.0.0.1:8082"
rm -f "$env_file"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
