# Deploying a compose app

For a Target made of several containers — as opposed to a static site plus a
jar, which `askus` is. See ADR-0006 for why this exists and ADR-0003 for why a
Candidate is checked before Cutover.

## What happens when you merge

1. CI builds each image and pushes it to `ghcr.io/<owner>/<repo>/<name>`.
2. CI sends the server a short manifest naming those images **by digest**.
3. The server pulls them. Nothing is built on the server.
4. The server reads the pending database migrations. If any one of them drops,
   renames, retypes or newly forbids null on something that already exists, the
   deploy **stops here** and your phone says which migration and which line.
   Nothing has been applied and nobody has been served anything new.
5. Otherwise the candidate containers start on local-only ports, sharing the
   live database, and are checked until they answer.
6. Only then does the live stack move to the new images, and the site is
   checked again. If that fails, the previous images are restored.

The database container is never recreated, restarted or upgraded by a deploy.

## Adding an app

The work is split across two repositories on purpose: this one never changes
another repo's code. Steps 1 and 2 happen here. Steps 3 to 5 are for a session
working on the app's own repository, which can be pointed at this page.

### In this repository

**1. Add a block to `server/md-deploy-root`.** This is the only thing that
makes an app deployable at all, and it is deliberately manual — the list is the
reason a leaked key from one repo cannot touch anything else on the machine.

```bash
  yourapp)
    APP_KIND=compose
    APP_DIR=/opt/yourapp
    COMPOSE_FILE=docker-compose.prod.yml
    REGISTRY_PREFIX=ghcr.io/owner/repo        # lowercase, as ghcr stores it
    LIVE_NETWORK=yourapp_default              # docker network ls
    BACKEND_PORT=3000
    BACKEND_HEALTH_PATHS="/health /lists"     # must return 200, inside the container
    CANDIDATE_BACKEND_PORT=13000              # unused, localhost only
    CANDIDATE_FRONTEND_PORT=18080
    MIGRATION_STYLE=prisma                    # or `none`
    ;;
```

**2. Add the app to the `ONBOARDED_REPOS` secret** so the audit watches it
(`docs/audit.md`).

### In the app's repository

**3. Make the app's compose file take images rather than build them.** Replace
each `build:` block with `image: ${BACKEND_IMAGE}` / `image: ${FRONTEND_IMAGE}`.
The dispatcher sets those two values in the app's `.env` at Cutover, and keeps
the previous ones so it can put them back.

**4. Add the deploy workflow to the repo.**

```yaml
name: Deploy
on:
  push:
    branches: [main]
  workflow_dispatch: {}

jobs:
  deploy:
    uses: ethichadebe/workflows/.github/workflows/compose-deploy.yml@main
    permissions:
      contents: read
      packages: write
    with:
      app: yourapp
      backend-dockerfile: backend/Dockerfile
      frontend-dockerfile: frontend/Dockerfile
    secrets: inherit
```

The repo needs `VPS_DEPLOY_KEY`, `VPS_HOST`, `TELEGRAM_BOT_TOKEN` and
`TELEGRAM_CHAT_ID`.

**5. Let the server read the images.** Packages pushed to ghcr start private.
For a public repo, make both packages public under the repository's Packages
settings. For a private one, `docker login ghcr.io` on the box once with a
read-only token.

**Order matters.** Do steps 1 and 2 first and install the dispatcher, then the
app's own change. Leave any existing deploy in place until the new path has
succeeded once — removing the old one first leaves the app with no way to ship
if something needs a second attempt.

## Installing an updated dispatcher

The two scripts in `server/` are not deployed by anything — deploying the thing
that does deploys is how you lock yourself out. Copy them up by hand after they
change:

```bash
scp server/md-deploy server/md-deploy-root root@SERVER:/tmp/
ssh root@SERVER 'install -o root -g root -m 0755 /tmp/md-deploy      /usr/local/bin/md-deploy
                 install -o root -g root -m 0755 /tmp/md-deploy-root /usr/local/sbin/md-deploy-root'
```

Then check it answers, without deploying anything:

```bash
ssh -i ~/.ssh/md_deploy deploy@SERVER 'status yourapp'
```

## When it refuses a migration

You get a message naming the migration and the offending line, and nothing has
changed. Apply that one deliberately — usually by splitting it into an additive
step now and the destructive step after the new code is live everywhere — then
merge again.

This is the intended behaviour, not a fault. Roughly: adding is safe to
automate, removing is not.

## Checking the rules still hold

```bash
bash server/md-deploy-root.test.sh
```

Runs anywhere, needs no server, and covers what the dispatcher accepts as an
image, what it treats as a destructive migration, and how it edits `.env`
without disturbing the other values.
