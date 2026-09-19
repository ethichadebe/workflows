#!/usr/bin/env bash
# Mobile Delivery: check every Onboarded repo against the decisions in docs/adr/.
#
#   REPOS="owner/one
#   owner/two" AUDIT_TOKEN=github_pat_... bash scripts/audit-onboarded.sh
#
# Onboarding happens one repo at a time, weeks apart, from a Cloud session that
# can only see the repo it was started on. So the second repo gets solved from
# scratch, the decisions in docs/adr/ get re-made differently, and nobody
# notices until a deploy asks for a human at a keyboard. This is the one place
# that looks at all of them at once.
#
# Read-only: it fetches file trees and workflow files and prints Markdown. It
# needs a token that can read every Onboarded repo — see docs/audit.md.
#
# Exits 1 when anything was found, so the workflow can alert on it.
set -uo pipefail

API="${GITHUB_API_URL:-https://api.github.com}"
REGISTRY_FILE="${REGISTRY_FILE:-server/md-deploy-root}"
TOKEN="${AUDIT_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  echo "AUDIT_TOKEN is not set. The audit reads other repositories, which the" >&2
  echo "workflow's own GITHUB_TOKEN cannot do. See docs/audit.md." >&2
  exit 2
fi

# One `owner/repo` per line. Blank lines and `#` comments are ignored, so the
# list can say why a repo is on it.
repos=$(printf '%s\n' "${REPOS:-}" |
  tr -d '\r' | sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')

if [ -z "$repos" ]; then
  echo "REPOS is empty, so this audit would pass without checking anything." >&2
  echo "Set the ONBOARDED_REPOS secret to one owner/repo per line." >&2
  exit 2
fi

# The apps the deploy dispatcher will act on. A repo whose deploy names an app
# that is not here cannot deploy at all: the dispatcher refuses it (ADR-0004).
registry=""
if [ -f "$REGISTRY_FILE" ]; then
  registry=$(grep -oE '^  [a-z0-9-]+\)' "$REGISTRY_FILE" | tr -d ' )')
else
  echo "warning: $REGISTRY_FILE not found; app registry checks skipped" >&2
fi

BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT

# Prints the HTTP code; the body lands in $BODY. The code is printed rather
# than assigned because every caller wants it from a command substitution, and
# a variable set inside one never reaches the caller.
api() {
  curl -sS -m 30 -o "$BODY" -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: ${2:-application/vnd.github+json}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$API/$1" 2>/dev/null || echo 000
}

raw() { api "$1" "application/vnd.github.raw"; }

total=0
clean=0
repo_count=0

printf '# Onboarded repo audit\n\n'
printf '_%s_\n' "$(date -u '+%Y-%m-%d %H:%M UTC')"

for repo in $repos; do
  repo_count=$((repo_count + 1))
  findings=""
  note() { findings="${findings}$(printf '\n- %s' "$1")"; }
  count_findings() { printf '%s' "$findings" | grep -c '^- ' || true; }

  printf '\n## %s\n\n' "$repo"

  code=$(api "repos/$repo")
  if [ "$code" != "200" ]; then
    printf -- '- **cannot be read** (HTTP %s). The audit token has to be allowed to see this repository, or it should come off the list.\n' "$code"
    total=$((total + 1))
    continue
  fi
  branch=$(jq -r '.default_branch // "main"' < "$BODY")

  code=$(api "repos/$repo/git/trees/$branch?recursive=1")
  if [ "$code" != "200" ]; then
    printf -- '- **file list unavailable** (HTTP %s on the `%s` tree).\n' "$code" "$branch"
    total=$((total + 1))
    continue
  fi
  paths=$(jq -r '.tree[]?.path' < "$BODY")
  [ "$(jq -r '.truncated' < "$BODY")" = "true" ] &&
    note 'the file list came back truncated, so the checks below saw only part of the repo'

  has() { printf '%s\n' "$paths" | grep -qxF "$1"; }
  matching() { printf '%s\n' "$paths" | grep -E "$1" || true; }
  listed() { printf '%s' "$1" | tr '\n' ' ' | sed 's/^ *//; s/ *$//; s/ /, /g'; }

  # ── Conventions (ONBOARDING.md steps 1, 3 and 4) ────────────────────────────
  if has CLAUDE.md; then
    if [ "$(raw "repos/$repo/contents/CLAUDE.md")" = "200" ] &&
       ! grep -q '^## Mobile Delivery' "$BODY"; then
      note 'CLAUDE.md has no `## Mobile Delivery` section, so a session on this repo is not told to open a pull request, run the checks, or write a change note'
    fi
  else
    note 'no CLAUDE.md, so a session on this repo starts with none of the conventions'
  fi

  has docs/journal/README.md ||
    note 'no `docs/journal/README.md`, so there are no change notes and the workflow cannot be judged on how it actually performs'
  has .claude/settings.json ||
    note 'no `.claude/settings.json`, so a Cloud session here starts without the plugins — they are not inherited from anyone'"'"'s laptop'

  # ── Workflows ───────────────────────────────────────────────────────────────
  workflows=$(matching '^\.github/workflows/.*\.ya?ml$')
  [ -z "$workflows" ] && note 'no workflows at all: nothing checks a pull request and nothing deploys'

  apps=""
  deploys=""
  copied=""
  for wf in $workflows; do
    [ "$(raw "repos/$repo/contents/$wf")" = "200" ] || continue

    # ADR-0001: the automation lives in one repository so a fix lands
    # everywhere at once. A pull request check that sets up a toolchain itself
    # is a copy of the shared checks that will never get that fix. Only
    # pull-request workflows are judged this way: a deploy has to build the
    # artifact itself, since there is no shared deploy workflow to call yet.
    if grep -qE '^[[:space:]]*pull_request:' "$BODY" &&
       grep -qE 'uses:[[:space:]]*actions/setup-(node|java)@' "$BODY" &&
       ! grep -q 'uses: ethichadebe/workflows/' "$BODY"; then
      copied="${copied} ${wf##*/}"
    fi

    # A deploy is anything that speaks to the dispatcher.
    if grep -qE '(frontend|backend)-(upload|cutover)' "$BODY"; then
      deploys="${deploys} ${wf##*/}"
      app=$(grep -oE '^[[:space:]]*APP:[[:space:]]*[a-z0-9-]+' "$BODY" | head -1 | awk '{print $2}')
      [ -n "$app" ] && apps="$apps $app"
    fi
  done

  [ -n "$copied" ] &&
    note "carries its own copy of the shared checks ($(listed "$copied")). A fix to how checks work will never reach this repo — call \`ethichadebe/workflows/.github/workflows/node-checks.yml@main\` instead (ADR-0001)."

  # ── Deploys ─────────────────────────────────────────────────────────────────
  # ADR-0003 and ADR-0004: CI builds the artifact, hands it to the dispatcher as
  # a Candidate, and the Candidate is checked before Cutover. Anything that
  # instead pulls and rebuilds on the server has cut over before it checked, and
  # had to be installed by hand on the box in the first place.
  on_box=$(matching '(\.service|\.timer)$|auto-deploy')
  if [ -n "$deploys" ]; then
    for app in $apps; do
      printf '%s\n' "$registry" | grep -qxF "$app" ||
        note "deploys as app \`$app\`, which the dispatcher does not know. Every run is refused until an \`$app)\` block is added to \`server/md-deploy-root\` (ADR-0004)."
    done
    [ -z "$apps" ] &&
      note 'has a deploy workflow but no `APP:` the audit could read, so it cannot be checked against the dispatcher registry'
    [ -n "$on_box" ] &&
      note "also deploys from the server itself ($(listed "$on_box")). Two things deploying the same app will fight."
  elif [ -n "$on_box" ]; then
    note "deploys from the server itself ($(listed "$on_box")) rather than through the dispatcher. The new version is live before it is checked, which ADR-0003 rules out, and installing or fixing it needs someone at the box — the thing Mobile Delivery exists to avoid."
  else
    note "nothing deploys it. Merging a pull request changes what is on \`$branch\` and nothing else, so someone has to go to the server by hand."
  fi

  # ── Secrets ─────────────────────────────────────────────────────────────────
  # Names only; values are never returned. Skipped silently without the
  # permission, so a token without it still gives a useful audit.
  if [ -n "$deploys" ] && [ "$(api "repos/$repo/actions/secrets?per_page=100")" = "200" ]; then
    names=$(jq -r '.secrets[]?.name' < "$BODY")
    for want in VPS_DEPLOY_KEY VPS_HOST TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID; do
      printf '%s\n' "$names" | grep -qxF "$want" ||
        note "deploys but has no \`$want\` secret, so the deploy fails at the first step that needs it."
    done
  fi

  if [ -z "$findings" ]; then
    printf 'OK\n'
    clean=$((clean + 1))
  else
    total=$((total + $(count_findings)))
    printf '%s\n' "${findings#$'\n'}"
  fi
done

printf '\n---\n\n%s of %s repo(s) clean, %s finding(s).\n' "$clean" "$repo_count" "$total"

[ "$total" -eq 0 ] || exit 1
