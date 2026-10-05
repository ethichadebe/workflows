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

echo "a merge commit reports the change, not the branch name"
# Nearly every deploy here is a merge, so this is the common case, not an edge.
msg() {
  NOTIFY_RENDER_ONLY=1 EVENT=deploy-ok SEED=1 APP=portfolio COMMIT="$1" \
    bash "$here/notify.sh"
}

m=$(msg "$(printf 'Merge pull request #13 from ethichadebe/claude/fervent-rubin-1mk2v3\n\nfeat: ship the redesign, with lint cleared')")
want    "the change is reported"      "$m" "feat: ship the redesign, with lint cleared"
want    "the PR number is kept"       "$m" "(#13)"
wantnot "the branch name is dropped"  "$m" "fervent-rubin"
wantnot "the merge boilerplate is dropped" "$m" "Merge pull request"

m=$(msg "$(printf 'Merge branch '"'"'main'"'"' into feature\n\nfix: the thing')")
want    "a plain branch merge also reports the change" "$m" "fix: the thing"
wantnot "no stray PR number"                           "$m" "(#"

# A merge with no body is all we have, so it has to survive rather than vanish.
m=$(msg "Merge pull request #13 from ethichadebe/some-branch")
want "a bodyless merge still says something" "$m" "Merge pull request #13"

# An ordinary commit must be untouched by any of the above.
m=$(msg "$(printf 'fix the login redirect\n\na long body nobody needs on a phone')")
want    "an ordinary subject is kept" "$m" "fix the login redirect"
wantnot "its body is still dropped"   "$m" "nobody needs"

# A squash merge already carries the number in the subject; do not double it.
m=$(msg "feat: add the thing (#42)")
want    "a squash subject is kept as is" "$m" "feat: add the thing (#42)"
wantnot "no doubled number"              "$m" "(#42) (#"

echo "the Claude line is strictly an addition"
# It is allowed to be absent, wrong, or slow. It is never allowed to change a
# fact, reshape a message, or reach the one alert that must not wait.

# 1. No key is the default, and must be byte-for-byte what shipped before it.
with=$(render deploy-ok 7)
without=$(NOTIFY_RENDER_ONLY=1 NOTIFY_NO_FLAVOUR=1 EVENT=deploy-ok SEED=7 APP="askus" \
  COMMIT="fix the login redirect" \
  RUN_URL="https://github.com/o/r/actions/runs/123" bash "$here/notify.sh")
if [ "$with" = "$without" ]; then ok; else
  fail=$((fail + 1)); printf 'FAIL: no key changed the message\n  %s\n  %s\n' "$with" "$without"
fi

# 2. flavour.sh must not reach the network for the events it has no business
#    on. A fake key proves it returns before curl rather than because of it.
for ev in site-down drift not-an-event; do
  out=$(ANTHROPIC_API_KEY=sk-not-a-real-key EVENT=$ev APP=askus \
    COMMIT="fix the login redirect" bash "$here/flavour.sh" 2>/dev/null)
  if [ -z "$out" ]; then ok; else
    fail=$((fail + 1)); echo "FAIL: flavour.sh spoke on $ev: $out"
  fi
done

# 3. A commit with nothing in it has nothing to react to.
out=$(ANTHROPIC_API_KEY=sk-not-a-real-key EVENT=deploy-ok APP=askus COMMIT="   " \
  bash "$here/flavour.sh" 2>/dev/null)
if [ -z "$out" ]; then ok; else fail=$((fail + 1)); echo "FAIL: spoke on an empty commit"; fi

# 4. With a stub standing in for the API, the line is appended and escaped,
#    and no stub output can break the message apart.
stub_dir=$(mktemp -d)
cp "$here/notify.sh" "$here/voice.sh" "$stub_dir/"
stub() { printf '#!/usr/bin/env bash\nprintf %%s %s\n' "$(printf '%q' "$1")" > "$stub_dir/flavour.sh"; }
run_stub() {
  NOTIFY_RENDER_ONLY=1 EVENT=deploy-ok SEED=7 APP="askus" \
    COMMIT="fix the login redirect" RUN_URL="https://example.com/r/1" \
    bash "$stub_dir/notify.sh" 2>/dev/null
}

stub "The dance survived the port."
m=$(run_stub)
want "the line is appended"        "$m" "The dance survived the port."
want "the facts are still there"   "$m" "askus"
want "the commit is still there"   "$m" "fix the login redirect"

stub '</i><script>alert(1)</script>'
m=$(run_stub)
wantnot "a script tag cannot survive" "$m" "<script>"
want    "it is escaped instead"       "$m" "&lt;script&gt;"

stub "$(printf 'line one\nline two\nline three')"
m=$(run_stub)
lines_added=$(printf '%s' "$m" | grep -c 'line one')
if [ "$lines_added" = "1" ]; then ok; else
  fail=$((fail + 1)); echo "FAIL: a multi-line answer did not stay one line"
fi
want  "its later lines are folded in"      "$m" "line two"

stub ""
m=$(run_stub)
if [ "$m" = "$without" ]; then ok; else
  fail=$((fail + 1)); printf 'FAIL: an empty answer changed the message\n  %s\n' "$m"
fi
rm -rf "$stub_dir"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
