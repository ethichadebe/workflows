# A Candidate is checked before Cutover, never after

A failed deploy must not affect the Live version. So every Candidate is checked while users are still on the Live version, and Cutover happens only once the Candidate passes; a failing Candidate is discarded and users never reach it. For a backend this means briefly running the Candidate alongside the Live version on a second port and switching traffic to it only after it answers correctly, which is why two copies of the same service can be seen running during a deploy.

## Considered Options

- **Cut over first, check, roll back on failure.** This is how deploys first worked. It is simpler, but users are served a broken version for as long as the check takes — seconds for a static site, up to about two and a half minutes for the backend.
