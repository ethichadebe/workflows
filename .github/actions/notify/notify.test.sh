#!/usr/bin/env bash
# Guards the facts against the voice.
#
# The point of a personality is that the wording changes. The point of these
# tests is that changing the wording cannot quietly drop the app name, the "your
# site is fine" reassurance or the link — the three things that decide whether a
# message at 2am is useful or frightening.
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
pass=0
fail=0

render() {
  NOTIFY_RENDER_ONLY=1 EVENT="$1" SEED="$2" \
    APP="askus" \
    COMMIT="fix the login redirect" \
    RUN_URL="https://github.com/o/r/actions/runs/123" \
    DETAIL="- www.ethichadebe.me returned 502" \
    bash "$here/notify.sh"
}

want() { # want <description> <haystack> <needle>
  if printf '%s' "$2" | grep -qF -- "$3"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  wanted to find: %s\n  in: %s\n' "$1" "$3" "$2"
  fi
}

wantnot() {
  if printf '%s' "$2" | grep -qF -- "$3"; then
    fail=$((fail + 1))
    printf 'FAIL: %s\n  should not contain: %s\n  in: %s\n' "$1" "$3" "$2"
  else
    pass=$((pass + 1))
  fi
}

echo "every seed keeps the facts"
# Covers every branch of `pick` many times over, whatever the voice chooses.
for seed in 0 1 2 3 4 5 6 7 8 9 17 23 99 100 12345 987654321; do
  ok=$(render deploy-ok "$seed")
  want "deploy-ok names the app (seed $seed)" "$ok" "askus"

  bad=$(render deploy-failed "$seed")
  want "deploy-failed names the app (seed $seed)" "$bad" "askus"
  want "deploy-failed links the run (seed $seed)" "$bad" "/actions/runs/123"
  # The reassurance may be worded any way, so match the idea, not a sentence.
  if printf '%s' "$bad" | grep -qiE 'untouched|still serving|unchanged|nothing shipped|never went live|is safe'; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: deploy-failed must say the live version is safe (seed %s)\n  in: %s\n' "$seed" "$bad"
  fi

  down=$(render site-down "$seed")
  want "site-down links the run (seed $seed)" "$down" "/actions/runs/123"

  drift=$(render drift "$seed")
  want "drift links the run (seed $seed)" "$drift" "/actions/runs/123"
  if printf '%s' "$drift" | grep -qiE 'nothing is down|no outage|not an outage|still up|nothing is broken'; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: drift must say nothing is down (seed %s)\n  in: %s\n' "$seed" "$drift"
  fi
done

echo "the same run always renders the same message"
a=$(render deploy-failed 4242)
b=$(render deploy-failed 4242)
if [ "$a" = "$b" ]; then pass=$((pass + 1)); else
  fail=$((fail + 1)); echo "FAIL: two renders of one run differed"
fi

echo "a commit message cannot break the markup"
hostile=$(NOTIFY_RENDER_ONLY=1 EVENT=deploy-ok SEED=1 APP="askus" \
  COMMIT='fix a < b & </b><script>alert(1)</script>' \
  bash "$here/notify.sh")
wantnot "no raw script tag survives" "$hostile" "<script>"
wantnot "no raw closing bold survives" "$hostile" "</b><"
want    "the ampersand is escaped" "$hostile" "&amp;"
want    "the less-than is escaped" "$hostile" "&lt;"

echo "an unknown event still delivers the facts"
unknown=$(NOTIFY_RENDER_ONLY=1 EVENT=not-a-real-event SEED=1 APP="askus" \
  COMMIT="fix the login redirect" RUN_URL="https://example.com/run/9" \
  bash "$here/notify.sh")
want "the fallback names the app" "$unknown" "askus"
want "the fallback links the run" "$unknown" "https://example.com/run/9"

echo "a missing app name does not render an empty gap"
noapp=$(NOTIFY_RENDER_ONLY=1 EVENT=deploy-ok SEED=1 COMMIT="x" bash "$here/notify.sh")
wantnot "no empty bold tag" "$noapp" "<b></b>"

echo "a multi-line commit message is cut to its subject"
multi=$(NOTIFY_RENDER_ONLY=1 EVENT=deploy-ok SEED=1 APP=askus \
  COMMIT="$(printf 'the subject line\n\nthe body nobody needs on a phone')" \
  bash "$here/notify.sh")
want    "the subject is kept" "$multi" "the subject line"
wantnot "the body is dropped" "$multi" "nobody needs"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
