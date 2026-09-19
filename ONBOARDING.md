# Onboarding a repository to Mobile Delivery

You are a Claude Code session working on one GitHub repository. Someone has asked you to onboard it to **Mobile Delivery**: a workflow where changes are described from a phone, checked automatically, merged by a human, and deployed on merge.

Do the work below, then **open a pull request**. Do not merge it.

## First, understand the repo

Work out its **Targets**: the buildable parts, each with its own setup, test and build commands. A Target is usually a folder with its own `package.json`, `pom.xml`, `pubspec.yaml` or similar.

For each Target, find the real commands by reading the project's files, not by guessing. In a `package.json`, read `scripts`. If a command does not exist, leave it out rather than inventing one — a workflow that runs `npm test` when no test script exists fails on every pull request and teaches people to ignore red.

Say what you found in the pull request description.

## 1. Add the conventions to the repo's instructions file

Add this section near the top of `CLAUDE.md` (create the file if it does not exist), keeping any existing content:

```md
## Mobile Delivery

This repository ships through Mobile Delivery: someone describes a change from their phone, you open a pull request, they merge, and it deploys itself. Follow this for **every** change, whether or not the request mentions it.

**Always:**

- Work on a branch and **open a pull request**. Never push to `main`, and never merge your own work — merging is the human's decision.
- **Run the checks before opening the PR**, so CI is not the first to find a problem. <!-- list the real commands for this repo here -->
- **Add a change note** to `docs/journal/` in the same pull request: a dated file saying what changed, whether it worked first time, whether a laptop was needed, and anything that got in the way. See `docs/journal/README.md`.
- Keep the pull request description short and plain: what changed, and why.

**Never:**

- Put server addresses, IP addresses, keys or secrets in this repo.
- Edit anything in `.github/workflows/` unless the request is explicitly about the pipeline.
- Add a dependency without saying in the PR description why it is needed.
```

Replace the comment with this repo's real commands, one line per Target.

## 2. Add the checks

Create `.github/workflows/ci.yml` calling the shared checks, one job per Target. Include only the commands that exist.

```yaml
name: CI

on:
  pull_request:
  workflow_dispatch: {}

jobs:
  frontend:
    uses: ethichadebe/workflows/.github/workflows/node-checks.yml@main
    with:
      working-directory: frontend
      lint: npm run lint
      test: npm run test:run
      build: npm run build

  backend:
    uses: ethichadebe/workflows/.github/workflows/maven-checks.yml@main
    with:
      working-directory: backend/api
```

Adjust the job names, folders and commands to this repo. A single-Target repo has one job; use `.` as the working directory when the project sits at the repo root.

If the repo already has a workflow doing the same thing, replace it and say so in the pull request description, so the same checks are maintained in one place from now on.

## 3. Add the journal

Create `docs/journal/README.md`:

```md
# Journal

## Change notes

One per change that ships, added in the same pull request as the change itself, so the workflow can be judged on how it actually performs.

Name them `YYYY-MM-DD-short-slug.md` and keep them short:

- **Asked for:** what was requested.
- **Worked first time:** yes or no, and what went wrong if no.
- **Laptop needed:** yes or no.
- **Friction:** what got in the way. Be honest — "had to explain it twice" is the useful entry.

## Never put in here

Server addresses, IP addresses, credentials, or anything that would matter if a stranger read it.
```

Then add the first change note, for this onboarding itself.

## 4. Make the skills available

Cloud sessions do not inherit plugins from anyone's laptop, so declare them in the repo. Create `.claude/settings.json`, or merge into the existing one without removing anything:

```json
{
  "enabledPlugins": {
    "mattpocock-skills@claude-plugins-official": true
  }
}
```

## 5. Ask to be put on the audit list

Nothing else compares Onboarded repos to each other, so a repo that is not on the list drifts unnoticed. You cannot set the secret yourself, so end the pull request description with one line:

> Add `owner/repo` to the `ONBOARDED_REPOS` secret in `ethichadebe/workflows` after merging.

See `docs/audit.md` in that repository for what the audit then checks.

## What onboarding does **not** do

**It does not set up deploys.** A repo needs a Destination — somewhere to ship to — and each kind of Destination has to exist on the server first. Onboarding gives the repo its checks, its conventions and its journal. Deploys are added afterwards, by someone with server access.

Say this plainly in the pull request description, so nobody merges it expecting the repo to start deploying.

**Do not invent a deploy to fill the gap.** A timer on the server that pulls and rebuilds looks like it solves this, and does not: it makes a new version Live before anything has checked it, which ADR-0003 rules out, and it has to be installed and repaired by hand on the box — the exact thing this workflow exists to avoid. A deploy reaches the server through the locked dispatcher or it waits. Say in the pull request description which Destination this repo will need, so whoever adds the matching action to the dispatcher knows what to build.

## The pull request

Title it `chore: onboard to Mobile Delivery`. In the description, cover:

- the Targets you found, and the commands you chose for each,
- anything you deliberately left out, and why,
- that deploys are **not** included yet, and which Destination the repo will need,
- the line asking for the repo to be added to `ONBOARDED_REPOS`,
- anything about the repo that will make deploying awkward later, such as a build that needs secrets, or tests that need a database.

That last point is the most valuable thing you can write. Whoever adds the Destination reads it first.
