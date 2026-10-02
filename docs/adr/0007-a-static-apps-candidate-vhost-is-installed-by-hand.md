# A static app's candidate vhost is installed by hand, not by the dispatcher

A static site's Candidate is checked by serving it on a localhost-only port and fetching the page and its first script, which means a web server has to be told where that folder is — one nginx vhost per static app. The dispatcher runs as root and could write that file and reload nginx itself, making a new static app fully automatic. It does not. The vhost is installed by a person, once, before the app's first deploy, exactly as the dispatcher's own app registry is.

ADR-0004 bought a specific promise: a deploy key leaked from any one repository can only redeploy apps already known to the server. A dispatcher that authors web-server configuration on request is a dispatcher that can publish a folder of its choosing, under a server name of its choosing, to the internet — which is a different and much larger thing than redeploying a known app. The convenience saved is one `install` command per app, perhaps twice a year.

## Considered Options

- **Have the dispatcher write the vhost and reload nginx.** Makes adding a static app a single registry edit. Rejected: it hands a leaked key the ability to serve arbitrary content from the box, and nginx config is the one file on the machine where a mistake is externally visible immediately.
- **One shared candidate vhost for every static app.** What exists today, where the vhost is hardcoded to `/opt/askus-frontend/frontend/dist.new`. Rejected because it is actively dangerous with more than one app: the second app's `frontend-cutover` would check the first app's candidate folder and pass, cutting over an unchecked site while reporting success.
- **Skip the Candidate check for static sites** and swap the folders directly. Rejected by ADR-0003; a static site is the cheapest possible thing to check, so there is no cost to justify it.

## Consequences

Adding a static app is two manual server steps rather than one: the registry block, and the candidate vhost on that app's own `CANDIDATE_PORT`. Both are written down in `docs/static-destination.md`.

Candidate ports are host-wide and must not collide — the same constraint the registry's other ports carry.
