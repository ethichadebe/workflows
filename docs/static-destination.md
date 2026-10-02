# Deploying a static site

For a Target that is a folder of files — no server process of its own. The
dispatcher already had the actions for this (`frontend-upload`,
`frontend-cutover`), because askus's site uses them; what was missing was a
shared workflow and a way to have more than one. See ADR-0003 for why a
Candidate is checked before Cutover, and ADR-0007 for why one of these steps
stays manual.

## What happens when you merge

1. CI builds the site, if it has a build, and packages the folder.
2. CI sends the archive to the dispatcher. Nothing is served from it yet.
3. The server unpacks it to `dist.new`, beside the live `dist`.
4. The server fetches `dist.new` through a **localhost-only nginx vhost** — the
   page, and the first script the page references. If either fails, `dist.new`
   is deleted and the live site is untouched.
5. Only then: two renames, `dist` → `dist.prev` and `dist.new` → `dist`, so a
   visitor never sees a missing folder. The live site is fetched once more, and
   restored from `dist.prev` if that fails.

## Adding an app

Steps 1 and 2 happen in this repository and on the server. Step 3 onwards is
for a session on the app's own repository — this repo never edits another.

### In this repository, and on the box

**1. Add a block to `server/md-deploy-root`:**

```bash
  yourapp)
    APP_KIND=static
    FRONT_DIR=/opt/yourapp            # will hold dist, dist.prev, dist.new
    SITE_HOST=yourapp.example         # the real domain, for the post-cutover check
    CANDIDATE_PORT=8091               # unused, localhost only, see below
    ;;
```

`CANDIDATE_PORT` must not collide with any other port in the registry. They are
host-wide, not per-app — askus already uses `8090` for its candidate vhost and
`18080` for its candidate API.

**2. Prepare nginx, as root.** Fetch the script rather than typing the vhosts
by hand — this box is already serving other sites, and a typo in an nginx file
is an outage. It is safe to re-run and changes nothing already correct.

```bash
curl -fsSL -o /tmp/add-static-app.sh \
  https://raw.githubusercontent.com/ethichadebe/workflows/main/server/add-static-app.sh
bash /tmp/add-static-app.sh yourapp yourapp.example 8091 /opt/yourapp
```

It creates the app's directory, the localhost-only candidate vhost on the port
you gave it, the live vhost, and a self-signed certificate if none exists —
then validates and reloads nginx. It refuses if the dispatcher has no block for
the app, or if another vhost already holds that port.

Both vhosts end in `try_files $uri $uri/ =404`, never a fallback to
`/index.html`. On the candidate vhost that is load-bearing: the cutover check
fetches the page **and the first script the page references**, and a fallback
answers a missing script with `index.html` and a 200 — so a build that lost its
assets passes the check and goes live broken. If the site becomes a single-page
app with client-side routes, change the **live** vhost's `=404` to
`/index.html`; leave the candidate vhost alone.

The certificate is self-signed on purpose: the deploy's own check uses
`curl -k`, so the whole path can be proven while DNS still points elsewhere.
Replace it with certbot once the domain resolves here.

This stays a person running a script rather than something the dispatcher does
— ADR-0007 says why.

> **If you are adding the second static app**, the vhost already on the box is
> `md-candidate.conf`, hardcoded to askus's folder. Leave it; it is askus's.
> Do not point it at two roots, and do not reuse port 8090 — a second app
> sharing that vhost would have its Candidate "checked" against askus's folder
> and pass without ever being looked at.

Then confirm, without deploying anything.

From a laptop holding the private deploy key:

```bash
ssh -i ~/.ssh/md_deploy deploy@SERVER 'status yourapp'
```

From the server itself, where that key does not exist and never should:

```bash
/usr/local/sbin/md-deploy-root status yourapp

# or, to exercise the locked path a real deploy takes, sudo rule included:
sudo -u deploy SSH_ORIGINAL_COMMAND='status yourapp' /usr/local/bin/md-deploy
```

Both lines read `404` before the first deploy — nginx is answering, but `dist`
and `dist.new` do not exist yet. A `000` means nginx is not listening where it
should be, and is the one to investigate.

### In the app's repository

**3. Add the deploy workflow.** A site with a build step:

```yaml
name: Deploy
on:
  push:
    branches: [main]
  workflow_dispatch: {}

jobs:
  deploy:
    uses: ethichadebe/workflows/.github/workflows/static-deploy.yml@main
    with:
      app: yourapp
      install: npm ci
      build: npm run build
      dist: dist
    secrets: inherit
```

A plain HTML site passes neither `install` nor `build`, and points `dist` at the
folder it already has:

```yaml
    with:
      app: yourapp
      dist: public
```

No toolchain is set up in that case, so the repo needs no `package.json`.

Check the branch name. The example says `main`; a repo whose default branch is
`master` and which copies it literally gets a workflow that never fires, and the
first symptom is a merge that silently does nothing.

**4. Secrets:** `VPS_DEPLOY_KEY`, `VPS_HOST`, `TELEGRAM_BOT_TOKEN`,
`TELEGRAM_CHAT_ID`.

**5. Add the app's repo to `ONBOARDED_REPOS`** so the audit watches it
(`docs/audit.md`).

## Moving a site that is live somewhere else

Do the move last. Get the whole path working while the old host still serves
users — point a hosts-file entry at the VPS, or check `SITE_HOST` through
`--resolve` as `status` does — and change DNS only once a deploy has succeeded
end to end. A failed deploy during setup then costs nothing at all, because
nobody is being served from the new box yet. It is the only time you get a
genuinely free first deploy; use it.

## The `expect` input

`static-deploy.yml` takes an optional `expect`: a string that must appear
somewhere in the built output, or the deploy fails before the server is touched.
Use it for a value the site is useless without — an API address, most often — so
a build that silently dropped it is caught in CI rather than by a visitor.
Leave it out for a site with no such value.
