# Delivery automation lives in one shared public repository

Every Onboarded repo calls its checks and deploys from a single `ethichadebe/workflows` repository rather than carrying its own copy, so a fix to how deploys work lands in every repo at once. It is public because GitHub only lets private repositories call automation stored in another private repository; roughly half of the active repos are public, and a private shared repo would silently exclude them. It holds automation only, never secrets, which each Onboarded repo keeps and passes in.

## Considered Options

- **Copy the automation into each repo.** Simplest to start, but every fix would have to be repeated per repo and copies drift.
- **A GitHub template for new projects, copies for existing ones.** Helps only projects that do not exist yet; nearly all real work is on existing repos.
- **A private shared repository.** Rejected because public repos cannot call it.
