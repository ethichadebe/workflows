## What this repository is for

Mobile Delivery's automation lives here: the shared checks, the shared deploys, the server-side dispatcher, onboarding and the audit. Its job is to make the workflow robust and seamless across every kind of Target and Destination — which means it has to know what the real repositories actually look like.

So it **reads** other repositories, and **never changes them**.

- Read any Onboarded repo freely. That is how drift is caught, and how a new kind of Destination gets designed from a real example rather than a guess.
- Never open a pull request, push a branch, or edit a file in another repository from a session on this one — not even a change this repo's own work makes necessary.
- Work that another repo needs is written down **here**, as instructions a session on that repo follows. `ONBOARDING.md` and `docs/compose-destination.md` are the pattern: this repo supplies the shared workflow, the dispatcher action and the instructions; the app's own repo makes its own change.
- The audit token is `Contents: Read-only` for the same reason — the one automated path into other repositories cannot write even if asked to.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the five default triage labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Onboarded repo audit

A scheduled job here reads every Onboarded repo and reports where it has drifted from `docs/adr/`. It is the only thing that sees more than one repo at a time. See `docs/audit.md`.
