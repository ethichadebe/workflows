# A compose app is a second kind of Destination, and its migrations are gated

The dispatcher knew one shape of app: a folder of static files and a single jar, which is what `askus` is. `accucery` is several containers built from source, with a database holding real data, and no action matched it — so the repo was given a timer on the server that pulls and rebuilds, putting a new version live before anything checked it and needing a person on the box to install and repair. A compose app is therefore a Destination in its own right: CI builds the images and pushes them to GitHub's registry, the dispatcher pulls them **by digest**, runs them beside the live version on local-only ports, and cuts over only once they answer. The database container is never touched by a deploy.

Its migrations are the part that cannot be made safe by checking alone. The candidate shares the live database, so a migration reaches live data while the previous version is still serving it. Additive changes — a new table, a new column, a new index — are invisible to the running code and leave a rollback safe. Anything that drops, renames, retypes or newly forbids null is not, so the dispatcher reads the pending migrations before applying any of them and **refuses the whole deploy** if it finds one, naming the file and the line. A migration state it cannot read for certain is refused too, rather than assumed harmless.

## Considered Options

- **Apply every migration and rely on the candidate check.** Fully hands-off, and still better than deploying blind, but a destructive migration breaks the live version in the seconds before Cutover — the one thing ADR-0003 promises cannot happen — and a rollback afterwards leaves old code facing a schema it does not understand.
- **Snapshot the database and check the candidate against the copy.** Safest against data loss, but the deploy grows with the data until it is slow enough that people stop trusting it, and the copy still has to be reconciled at Cutover.
- **Stream the built images over SSH, as the jar is.** Avoids a registry, but the backend image carries a Chromium install; roughly two gigabytes would cross the wire on every deploy. A registry moves only the layers that changed.

## Consequences

The server pulls from `ghcr.io`, so those packages must be readable by it: public for a public repo, or a read-only token on the box otherwise. Images are pinned to digests, so a repointed tag cannot slip past the check between the check and the Cutover.

A destructive migration is now a deploy that stops and messages you, rather than one that quietly succeeds. That is a person's job a few times a year, and the price of every other deploy being safe to ignore.
