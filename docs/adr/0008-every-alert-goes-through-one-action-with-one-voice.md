# Every alert goes through one action, and the voice is one file

Mobile Delivery's messages are the whole interface. A Change goes out from a phone and nothing is watched afterwards, so what arrives in Telegram is the only report there is. That text was written out five times — twice in `static-deploy.yml`, twice in `compose-deploy.yml`, once in `monitor.yml` and once in `audit.yml` — each a hand-rolled `curl` to `api.telegram.org` with its own wording. Five copies is five chances to drift, and already the deploy messages and the monitor message read as two different bots.

They now go through one composite action, `.github/actions/notify`, which owns the transport and the facts. Wording is decided in exactly one file inside it, `voice.sh`, where the bot is a named character — Spitjo, a Gauteng kasi guy who leads with whether you need to worry. A change of voice reaches askus, accucery and the website in a single pull request here, and no Onboarded repo changes a file, a step or a secret to receive it.

A composite action and not a shared script, because the shared deploy workflows run `actions/checkout` against the *calling* repository: nothing from this repo is on the runner's disk when they execute. The runner fetches an action on its own, so the action works from inside an Onboarded repo where a script cannot. For the same reason the `uses:` is pinned to `@main` rather than a relative path — `./` resolves against the caller's checkout, which is the app.

## The facts are not the voice's to lose

A personality exists to make the wording change, which is exactly what makes it dangerous here. Three things decide whether a message read while walking is useful or frightening: which app it concerns, whether the live version is still serving, and a link to the run. `notify.test.sh` renders every event at sixteen seeds and asserts those survive, matching the *idea* rather than a sentence — so the wording stays free and the facts do not. A voice that drops the reassurance from a failed deploy fails CI here instead of causing a panic at 2am.

## Considered Options

- **Keep the `curl` in each workflow and just reword them.** Rejected: it is the arrangement that produced two bots out of one, and the next Destination shape would produce a third.
- **A script in `scripts/`, called by the workflows.** Does not work. The deploy workflows execute with the app's repository checked out, so the file is not there.
- **Ask Claude to write each message at send time.** Rejected. It puts a network call and an unreviewable sentence in the one path that must not fail or mislead, and an outage is the worst moment for a third-party API to be slow. Phrasings are written once, committed, and chosen at send time by hashing the run id — so every message that can ever arrive has been read before it fires, the same run always renders the same text, and two deploys in a row still do not read identically.
- **Plain text instead of Telegram's HTML mode.** Would avoid escaping entirely. Rejected: a bold app name and a real link are most of the difference between a report and a wall of words. The escaping is done once, in `notify.sh`, with the hostile commit message in the test suite.

## Consequences

A Telegram outage no longer turns a deploy that worked into a red run, and no longer masks the failure it was reporting: the action logs the undelivered message to the run and exits 0. The run itself is still red or green on its own merits.

Adding an event kind means a `case` branch in `voice.sh` and a fact assertion in `notify.test.sh`. An unknown event still delivers the app, the commit and the link through a plain fallback, so a typo degrades rather than goes silent.
