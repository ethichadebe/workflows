#!/usr/bin/env bash
# SPITJO. This is the only file that decides what he sounds like. Change it
# freely; notify.sh and the workflows do not care.
#
# Spitjo is a Gauteng kasi guy. Unbothered when it works, straight with you when
# it doesn't, and he leads with whether you need to worry — because that is the
# first thing you want to know when your phone buzzes on a walk.
#
# He rarely says his own name, because Telegram already shows it as the sender.
# Repeating it in the body of every message would just be noise.
#
# What you get, already HTML-escaped and safe to drop into a message:
#   $E_APP     the app name            $E_COMMIT  the commit subject
#   $E_URL     link to the run         $E_DETAIL  extra lines (site checks)
#   variant N  a number 0..N-1, stable for this run: the same run always
#              renders the same message, but two deploys in a row do not read
#              identically. Each phrasing is written out whole, so you can read
#              every message this file can ever send.
#
# Telegram HTML: <b> <i> <code> <a href="…"> only. Anything else is rejected.
#
# The one rule: whatever the voice, these must survive it —
#   deploy-failed  names the app, says the live version is untouched, links the run
#   site-down      links the run
#   drift          says nothing is down, links the run
# notify.test.sh asserts exactly that at sixteen seeds, so a voice that loses a
# fact fails CI rather than failing you at 2am.

voice_render() {
  case "$1" in

    deploy-ok)
      case "$(variant 5)" in
        0) printf '✅  Sharp sharp — <b>%s</b> is live.\n     <i>%s</i>' "$E_APP" "$E_COMMIT" ;;
        1) printf '✅  Ayoba. <b>%s</b> is live.\n     <i>%s</i>' "$E_APP" "$E_COMMIT" ;;
        2) printf '✅  Sho, <b>%s</b> is up and running.\n     <i>%s</i>' "$E_APP" "$E_COMMIT" ;;
        3) printf '✅  Spitjo here — <b>%s</b> is live.\n     <i>%s</i>' "$E_APP" "$E_COMMIT" ;;
        *) printf '✅  <b>%s</b> is live. Nothing to see here.\n     <i>%s</i>' "$E_APP" "$E_COMMIT" ;;
      esac
      ;;

    deploy-failed)
      # The Candidate was discarded before it served anyone. The second line is
      # the whole point of this message: nothing is broken, nothing is urgent.
      case "$(variant 5)" in
        0) printf '⚠️  Ayeye. <b>%s</b> didn'\''t make it, mfethu.\n     But relax — the new one never went live.\n     Your site is still running as it was.\n     <i>%s</i>\n\n     <a href="%s">View the run</a>' "$E_APP" "$E_COMMIT" "$E_URL" ;;
        1) printf '⚠️  Yoh. <b>%s</b> fell at the last check.\n     Don'\''t stress, it never went live.\n     Your site is untouched.\n     <i>%s</i>\n\n     <a href="%s">View the run</a>' "$E_APP" "$E_COMMIT" "$E_URL" ;;
        2) printf '⚠️  Aowa. <b>%s</b> is not going out like that.\n     Thrown away before anyone saw it.\n     Your site is untouched, same as before.\n     <i>%s</i>\n\n     <a href="%s">View the run</a>' "$E_APP" "$E_COMMIT" "$E_URL" ;;
        3) printf '⚠️  Eish, <b>%s</b> didn'\''t pass, bro.\n     Nothing shipped — your site is still serving.\n     <i>%s</i>\n\n     <a href="%s">View the run</a>' "$E_APP" "$E_COMMIT" "$E_URL" ;;
        *) printf '⚠️  Hayi, <b>%s</b> is not ready.\n     It never went live, so nothing is broken.\n     Your site is untouched.\n     <i>%s</i>\n\n     <a href="%s">View the run</a>' "$E_APP" "$E_COMMIT" "$E_URL" ;;
      esac
      ;;

    site-down)
      # Not a Candidate that failed safely. Something that is actually serving
      # users is not answering, so he says so without softening it.
      case "$(variant 4)" in
        0) printf '🔴  Haibo. A site check failed.\n     This one is for real.%s\n\n     <a href="%s">View the run</a>' "${E_DETAIL:+$(printf '\n%s' "$E_DETAIL")}" "$E_URL" ;;
        1) printf '🔴  Yoh, something is down for real.%s\n\n     <a href="%s">View the run</a>' "${E_DETAIL:+$(printf '\n%s' "$E_DETAIL")}" "$E_URL" ;;
        2) printf '🔴  Eish. A site is not answering.%s\n\n     <a href="%s">View the run</a>' "${E_DETAIL:+$(printf '\n%s' "$E_DETAIL")}" "$E_URL" ;;
        *) printf '🔴  Awu, this one is not a drill.%s\n\n     <a href="%s">View the run</a>' "${E_DETAIL:+$(printf '\n%s' "$E_DETAIL")}" "$E_URL" ;;
      esac
      ;;

    drift)
      # A finding, not an outage. He leads with the calm so it is never mistaken
      # for the message above.
      case "$(variant 4)" in
        0) printf 'ℹ️  Yazi, these repos are drifting from the plan.\n     Nothing is down though.\n\n     <a href="%s">View the run</a>' "$E_URL" ;;
        1) printf 'ℹ️  Sho, some repos have wandered off the plan.\n     Nothing is down, relax.\n\n     <a href="%s">View the run</a>' "$E_URL" ;;
        2) printf 'ℹ️  Hayi bo, the repos are off the plan again.\n     Nothing is down — just housekeeping.\n\n     <a href="%s">View the run</a>' "$E_URL" ;;
        *) printf 'ℹ️  Eish, the repos have drifted from the plan.\n     Nothing is down. Whenever you have time.\n\n     <a href="%s">View the run</a>' "$E_URL" ;;
      esac
      ;;

  esac
}
