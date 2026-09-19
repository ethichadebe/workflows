# The onboarded repo audit

`scripts/audit-onboarded.sh` reads every Onboarded repo and reports where it has
drifted from the decisions in `docs/adr/`. `.github/workflows/audit.yml` runs it
every Monday morning and alerts on Telegram when it finds something. See
ADR-0005 for why it lives here.

Run it by hand from a Cloud session on this repo:

```bash
REPOS="ethichadebe/example" AUDIT_TOKEN=github_pat_... bash scripts/audit-onboarded.sh
```

It only reads. It exits 1 when it finds anything, and prints Markdown.

## The access it needs

The workflow's own `GITHUB_TOKEN` can only see this repository, so the audit
needs one of its own. Create a **fine-grained personal access token**:

- **Repository access:** every Onboarded repo. Not "all repositories" — the
  list should have to be extended deliberately, the same way repos are
  onboarded one at a time.
- **Permissions:** `Contents: Read-only` and `Metadata: Read-only`. Nothing
  else. It must not be able to write anywhere.
- Optionally `Secrets: Read-only`, which returns secret **names** and never
  values. With it the audit also notices a repo that deploys but is missing
  `VPS_DEPLOY_KEY`; without it those checks are skipped silently.

Then set two repository secrets here:

| Secret | What it holds |
| --- | --- |
| `AUDIT_TOKEN` | the token above |
| `ONBOARDED_REPOS` | one `owner/repo` per line; `#` starts a comment |

The list is a secret rather than a file because this repository is public and
about half the Onboarded repos are private — the same reason the site monitor
keeps its targets in `MONITOR_TARGETS`. Do not put this repository itself on the
list: it is the shared automation, not an Onboarded repo, and every deploy and
convention check would report against it wrongly.

A Cloud session working on this repo can also be given access to the other
repositories directly, which is what makes a comparison possible while someone
is actually looking. That is granted outside this repo, by widening the Claude
GitHub App's repository access at
<https://github.com/apps/claude/installations/select_target>.

## What it checks, and why each one matters

| Finding | The decision behind it |
| --- | --- |
| Carries its own copy of the shared checks | ADR-0001. A fix to how checks work is supposed to land in every repo at once; a copy never receives it. Only pull-request workflows are judged, since a deploy must build its own artifact. |
| Deploys as an app the dispatcher does not know | ADR-0004. The deploy key is locked to a dispatcher that refuses any app without a block in `server/md-deploy-root`, so the repo's deploys fail every time until one is added. |
| Deploys from the server itself | ADR-0003 and ADR-0004. A timer on the box that pulls and rebuilds has made the new version Live before checking it, and it had to be installed by hand on the server in the first place. |
| Nothing deploys it | Merging changes the branch and nothing else, so shipping needs someone at a keyboard on the server. |
| Deploys but a deploy secret is missing | The run will fail at the first step that needs it. |
| No `## Mobile Delivery` section in `CLAUDE.md` | A session on that repo is never told to open a pull request, run the checks first, or write a change note. |
| No `docs/journal/README.md` | Without change notes there is no evidence of how the workflow actually performs. |
| No `.claude/settings.json` | Cloud sessions do not inherit plugins from anyone's laptop, so they must be declared in the repo. |

## Adding a check

Each rule is a few lines in the loop in `scripts/audit-onboarded.sh`, and each
one ends in a `note` saying what will go wrong, not just what is missing — a
finding nobody can act on gets ignored, and then so does the next one. Add a
rule only for something a decision in `docs/adr/` already settled.
