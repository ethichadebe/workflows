# Mobile Delivery

How a change travels from a request typed on a phone to running for real users, without the developer's laptop. It spans many GitHub repositories, so its words have to mean the same thing in every one of them.

## Sessions

**Cloud session**:
A Claude Code session that runs on Anthropic's infrastructure against one GitHub repository, started from the Claude app. The laptop plays no part in it.
_Avoid_: Remote session, web session, phone session

**Remote Control session**:
A Claude Code session running on the developer's own computer, steered from the phone. It needs that computer to be on, and is not part of Mobile Delivery.
_Avoid_: Cloud session, mobile session

## Repositories

**Onboarded repo**:
A repository that has been deliberately opted into Mobile Delivery. Repositories are onboarded one at a time, when work on them starts, never in bulk.
_Avoid_: Enabled repo, supported repo, connected repo

**Onboarding**:
The one-time act of making a repository an Onboarded repo, carried out from a Cloud session and ending in a pull request the developer merges.
_Avoid_: Setup, installation, migration

**Target**:
A buildable part of a repository, such as `frontend` or `backend`, with its own way of being set up, tested and built.
_Avoid_: Project, module, service, deploy target

**Destination**:
The place a Target ships to so that people can use it: a server, a static host, an app store. Some Targets have none.
_Avoid_: Deploy target, environment, host, server

**Live version**:
The version of a Target that users are being served right now at its Destination.
_Avoid_: Production build, current deploy, latest release

## Releasing

**Candidate**:
A newly built version of a Target that is at its Destination but not yet serving users. A Candidate either passes its checks and becomes the Live version, or is discarded without users ever reaching it.
_Avoid_: New build, staging version, release

**Cutover**:
The moment users stop being served the old Live version and start being served a Candidate that has already passed its checks. A Cutover never happens before those checks pass.
_Avoid_: Swap, go-live, release, deploy

**Alert**:
A message sent to the developer's phone when a Candidate fails its checks and no Cutover happens. The Live version is untouched when an Alert is sent.
_Avoid_: Notification, error, failure message

## Measuring

**Change**:
One request's full journey through Mobile Delivery, from being asked for in a Cloud session to either a Cutover or an Alert. Changes are what readiness is counted in.
_Avoid_: Task, ticket, deploy, update

**Change note**:
The developer's short account of how one Change went: whether it worked first time, whether the laptop was needed, and what got in the way. It lives in the Onboarded repo, beside the Change it describes.
_Avoid_: Log entry, feedback, retro
