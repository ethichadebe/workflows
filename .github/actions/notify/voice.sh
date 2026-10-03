#!/usr/bin/env bash
# THE VOICE. This is the only file that decides what the delivery bot sounds
# like. Change it freely; notify.sh and the workflows do not care.
#
# What you get, already HTML-escaped and safe to drop into a message:
#   $E_APP     the app name            $E_COMMIT  the commit subject
#   $E_URL     link to the run         $E_DETAIL  extra lines (site checks)
#   pick a b c  one of these, chosen by the run id: same run, same message,
#               but two deploys in a row do not read identically.
#
# Telegram HTML: <b> <i> <code> <a href="…"> only. Anything else is rejected.
#
# The one rule: a message is read on a phone, usually while walking, sometimes
# at night. Whatever the voice, these must survive it —
#   deploy-failed  names the app, says the live version is untouched, links the run
#   site-down      links the run
#   drift          says nothing is down, links the run
# notify.test.sh asserts exactly that, so a voice that loses a fact fails CI
# rather than failing you at 2am.

voice_render() {
  case "$1" in

    deploy-ok)
      printf '✅  <b>%s</b> is live.\n     <i>%s</i>' "$E_APP" "$E_COMMIT"
      ;;

    deploy-failed)
      # The candidate was discarded before it served anyone. The second line is
      # the whole point of this message: nothing is broken, nothing is urgent.
      printf '⚠️  <b>%s</b> deploy aborted at the candidate check.\n     %s\n     <i>%s</i>\n\n     <a href="%s">View the run</a>' \
        "$E_APP" \
        "$(pick 'Your live version is untouched, still serving.' \
                'The live version is untouched and still serving.' \
                'Nothing shipped. The live version is untouched.')" \
        "$E_COMMIT" "$E_URL"
      ;;

    site-down)
      printf '🔴  A site check failed.%s\n\n     <a href="%s">View the run</a>' \
        "${E_DETAIL:+$(printf '\n%s' "$E_DETAIL")}" "$E_URL"
      ;;

    drift)
      printf 'ℹ️  Onboarded repos have drifted from the delivery decisions.\n     Nothing is down.\n\n     <a href="%s">View the run</a>' \
        "$E_URL"
      ;;

  esac
}
