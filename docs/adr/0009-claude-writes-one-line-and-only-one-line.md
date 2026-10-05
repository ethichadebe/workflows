# Claude writes one line of each message, and only one line

ADR-0008 rejected asking Claude to write the messages, on the grounds that it puts a network call and an unreviewable sentence in the one path that must not fail or mislead. That reasoning was right about the delivery path and wrong about the sentence, and this supersedes that one bullet.

What it got wrong was the diagnosis. Eighteen committed phrasings rotate the greeting and leave the sentence identical: "X is live", then the commit subject. Spitjo never says anything *about* the change, because he has never read it. "Bring the dancing opening screen to the web version" went past him unremarked. No number of extra phrasings fixes that; only something that reads the change can.

So Claude writes one line, appended under the facts, and nothing else. `voice.sh` still renders the message; `notify.sh` still owns the transport and the escaping; `flavour.sh` can only add a line or stay silent. It runs behind a five-second timeout and `|| true`, so a slow, broken or rate-limited API produces exactly the message this repo would have sent anyway.

It never runs on `site-down`. That alert has to arrive immediately and read the same every time, and an outage is the worst moment to wait on a third-party API.

It is off unless `ANTHROPIC_API_KEY` is set in the Onboarded repo. Absence of the key is the off switch, so the first repo can try it for a week while the others are untouched, and turning it off anywhere is deleting a secret rather than shipping a change.

## What this costs, and it is not money

Before this, every message Spitjo could send had been read by a person before it fired — a property ADR-0008 argued for deliberately. That is now gone for one line of each message. A tone-deaf or unfunny sentence can reach a phone without anyone having seen it.

What holds the risk down: the facts sit above it and are untouched; the system prompt forbids praise, exclamation marks, emoji and restating the commit, and offers `SKIP` so a dull change gets no comment rather than a forced one; the answer is collapsed to one line, capped at 140 characters and HTML-escaped by the same function that escapes commit messages; and the generated line is logged into the run, so there is always a record of what was sent.

The commit subject reaching the model is text from a repository, so the system prompt names it as data and tells the model to ignore instructions inside it. The blast radius if that fails is one odd sentence in a private Telegram chat, which is why this is proportionate rather than a sandbox.

## Considered Options

- **More committed phrasings.** What ADR-0008 would have had us do. Rejected: the problem is that the sentence never responds to the change, and a longer list of greetings does not respond either.
- **Claude writes the whole message.** Rejected. The app name, the "your live version is untouched" reassurance and the run link are the message; they must be identical every time and must survive an API outage.
- **Opus, the house default.** Rejected here on latency, not cost. Opus always thinks and cannot be told not to, which spends seconds of a five-second budget on a twelve-word sentence. Haiku has no mandatory thinking. The bill either way is cents a year.
- **One shared key in this repo.** Not possible — the deploy workflows run in the Onboarded repo, so the key has to be that repo's. Making its absence the off switch turns that limitation into the rollout mechanism.

## Consequences

An Onboarded repo opting in adds a fifth secret. Nothing else changes for it: no file, no workflow edit.

`notify.test.sh` asserts the line can only add — that no key renders byte-for-byte what shipped before, that `flavour.sh` returns before the network on every event but the two it serves, that a hostile answer is escaped rather than rendered, that a multi-line answer stays one line, and that an empty answer leaves the message untouched. A stub stands in for the API so none of it needs a key or a network.
