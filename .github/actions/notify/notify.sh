#!/usr/bin/env bash
# Render one message in the delivery bot's voice and send it to Telegram.
#
# This file handles the facts and the transport. It never decides wording —
# that is voice.sh, so a change of voice cannot change what gets escaped, what
# gets sent, or whether a deploy is reported as failed.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

EVENT=${EVENT:?event is required}
APP=${APP:-}
COMMIT=${COMMIT:-}
RUN_URL=${RUN_URL:-}
DETAIL=${DETAIL:-}
SEED=${SEED:-0}

# Telegram's HTML parse mode treats these three as markup, and a commit message
# is user-written text that may contain any of them. Unescaped, "fix a < b" ends
# the message early or is rejected outright.
#
# Done with sed, not bash substitution: since bash 5.2 an "&" in a replacement
# string means "the text that matched", so ${s//</&lt;} yields "<lt;". In a sed
# replacement "\&" is an unambiguous literal ampersand on every version.
esc() {
  printf '%s' "${1-}" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# A commit message can be a paragraph. Only the subject belongs in a push alert.
subject() {
  local s=${1-}
  s=${s%%$'\n'*}
  if [ "${#s}" -gt 120 ]; then
    s="${s:0:119}…"
  fi
  printf '%s' "$s"
}

# Deterministic per run, varied across runs: the same run always renders the
# same message (so a re-read of an old alert is not a different alert), but two
# deploys in a row do not read identically.
seed_num() {
  local digits=${SEED//[^0-9]/} sum=0
  while [ -n "$digits" ]; do
    sum=$(( sum + ${digits:0:1} ))
    digits=${digits:1}
  done
  printf '%s' "$sum"
}

# pick "one" "two" "three" -> one of them, chosen by the seed.
pick() {
  local i=$(( $(seed_num) % $# ))
  shift "$i"
  printf '%s' "$1"
}

E_APP=$(esc "${APP:-the app}")
E_COMMIT=$(esc "$(subject "$COMMIT")")
E_DETAIL=$(esc "$DETAIL")
E_URL=$(esc "$RUN_URL")
export E_APP E_COMMIT E_DETAIL E_URL

# shellcheck source=voice.sh
. "$here/voice.sh"

text=$(voice_render "$EVENT" || true)

# The voice is allowed to be anything except absent. If it renders nothing —
# an unknown event, a typo in voice.sh — the facts still have to arrive.
if [ -z "${text//[[:space:]]/}" ]; then
  text=$(printf '%s: %s %s\n%s' "$EVENT" "$E_APP" "$E_COMMIT" "$E_URL")
fi

# NOTIFY_RENDER_ONLY lets the test suite read every message this can produce
# without a token and without sending anything.
if [ -n "${NOTIFY_RENDER_ONLY:-}" ]; then
  printf '%s\n' "$text"
  exit 0
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "notify: no Telegram credentials, message not sent:" >&2
  printf '%s\n' "$text" >&2
  exit 0
fi

# A Telegram outage must not turn a deploy that worked into a red run, and must
# not mask the failure that this message is reporting. So: log it, never fail.
if ! curl -sS --max-time 20 -o /dev/null \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "parse_mode=HTML" \
  --data-urlencode "disable_web_page_preview=true" \
  --data-urlencode "text=$text"; then
  echo "notify: Telegram rejected or did not answer. The message was:" >&2
  printf '%s\n' "$text" >&2
fi
