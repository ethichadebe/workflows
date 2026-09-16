# The deploy key can only run fixed deploy scripts

Onboarded repos reach a server through one SSH key, stored as a secret in each repo. Deploys have to run Docker, and any account allowed to run Docker can make itself root, so an ordinary `deploy` account in the Docker group would only look limited: one leaked repo secret would hand over the whole server. Instead the key is locked, on the server side, to a single dispatcher that accepts a short fixed list of actions for known apps (upload a Candidate, check it, cut over), and refuses everything else. A leaked key can then only redeploy the developer's own apps.

## Considered Options

- **A `deploy` account in the Docker group.** Quick to set up, but effectively root.
- **Keep using root's key.** The existing arrangement; any repo leak is a full server compromise, multiplied by every Onboarded repo holding the same key.

## Consequences

Each new kind of Destination needs a matching action in the dispatcher before a repo using it can be onboarded. Uploads go over the same locked key rather than a separate file-copy tool, since file-copy tools would be refused by the lock too.
