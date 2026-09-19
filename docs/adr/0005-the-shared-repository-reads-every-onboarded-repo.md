# The shared repository reads every Onboarded repo

Onboarding happens one repo at a time, from a Cloud session that can see only the repo it was started on. The second repo is therefore solved from scratch by someone who cannot read how the first one was solved, so the decisions recorded here get re-made differently, and the difference surfaces weeks later as a deploy that asks for a human at a keyboard. `ethichadebe/workflows` already holds those decisions, so it is also where they are checked: a scheduled audit reads every Onboarded repo through a read-only token and reports where each one has drifted. It reads repositories; it never writes to them.

## Considered Options

- **Trust the onboarding document.** What actually happened: two repos followed it and ended up with different deploys, because the document stops before deploys and says nothing about the dispatcher's app registry.
- **A check inside each Onboarded repo.** A repo cannot see what the others did, which is the whole problem, and a repo that was set up wrongly is exactly the one that will be missing the check.
- **Give each Cloud session access to every repository.** Useful for a session that is deliberately comparing repos, and worth having, but it catches a mistake only when someone happens to look.

## Consequences

The shared repository holds a token that can read every Onboarded repo, which is a new thing worth leaking. It is a fine-grained token limited to reading contents and metadata, it can write nothing, and it is the only credential here that reaches other repositories.

The list of Onboarded repos is a secret rather than a file, as the monitor's list of sites already is: roughly half the repos are private, and this repository is public.
