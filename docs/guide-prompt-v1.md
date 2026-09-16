# ChatGPT prompt — Mobile Delivery guide, v1

Paste everything below the line into ChatGPT.

---

You are writing a **v1 user guide** for a development workflow called **Mobile Delivery**. Write it for publication as a single Markdown document.

## Audience and tone

Readers are developers who understand the normal software lifecycle: branches, pull requests, CI, deployments. They have **not** seen this particular setup. Do not explain what Git, CI or a pull request is.

Write plainly and warmly, in short sections a reader can skim. **Aim for 1,200–1,800 words.** Prefer a short sentence to a clever one. No marketing language, no "unlock", no "seamless", no emoji headings.

## What Mobile Delivery is

A way to design, build, test and deploy real applications **from a phone**, with no laptop involved. The developer opens an AI coding session from a phone, describes a change, and the session works on the GitHub repository and opens a pull request. Automated checks run. The developer merges from the phone. The change then deploys itself, and the phone gets a message saying whether it worked.

## Vocabulary you must use consistently

Use these exact words with these meanings. Do not introduce synonyms.

- **Cloud session** — an AI coding session that runs on the provider's servers against one GitHub repository, started from a phone. The laptop plays no part.
- **Onboarded repo** — a repository deliberately opted into Mobile Delivery. Repos are onboarded one at a time, when work on them starts, never in bulk.
- **Onboarding** — the one-time act of making a repository an Onboarded repo, done from a Cloud session, ending in a pull request the developer merges.
- **Target** — a buildable part of a repository, such as a frontend or a backend, with its own setup, test and build commands.
- **Destination** — the place a Target ships to so people can use it: a server, a static host, an app store. Some Targets have none.
- **Live version** — the version of a Target users are being served right now.
- **Candidate** — a newly built version that is at its Destination but **not yet serving users**. It either passes its checks and becomes the Live version, or is discarded without users ever reaching it.
- **Cutover** — the moment users stop being served the old Live version and start being served a Candidate that has already passed its checks. A Cutover never happens before those checks pass.
- **Alert** — a message sent to the developer's phone when a Candidate fails its checks and no Cutover happens. The Live version is untouched when an Alert is sent.
- **Change** — one request's full journey, from being asked for in a Cloud session to either a Cutover or an Alert.

## How it works (the facts to describe)

**The everyday loop:**

1. The developer opens a Cloud session on an Onboarded repo from the phone and describes a Change.
2. The session edits the code and opens a pull request on its own branch.
3. Checks run on the pull request: lint, tests and a build, per Target.
4. The developer reviews and merges from the phone.
5. Merging triggers the deploy for whichever Targets changed.
6. The deploy builds the artifact **on CI, never on the server**, uploads it as a Candidate, checks the Candidate, and only then performs the Cutover.
7. The phone receives a message: live, or failed.

**How a Candidate is checked before Cutover:**

- A **website** Candidate is unpacked beside the Live version and served on a private local address that only the server can reach. The deploy fetches the page and the JavaScript file it references. Only if both answer correctly does it swap the folders, two renames, so visitors never see a missing site.
- An **API** Candidate is started in a container beside the Live one, on a local-only port, and polled until it answers correctly. Only then does it become Live. The previous build is kept, so a failure can be undone.

**The security model, which matters and should get its own short section:**

- Each Onboarded repo holds a deploy key as a secret.
- On the server, that key is **locked to a single dispatcher script**. Whatever the caller asks for arrives as text and is checked against a short list of allowed actions (upload a Candidate, check and cut over, report status) for apps named in a registry. Anything else is refused, including opening a shell.
- So a leaked repo secret can only redeploy the developer's own apps. It cannot take over the server.
- The apps' own ports are not published to the internet; a web server in front handles TLS. Passwords are off for SSH; keys only.

**What still needs a human:**

- Approving the work, by merging the pull request. That is the deliberate safety check.
- Anything needing a login the automation does not have, such as uploading a mobile app to a store.
- Diagnosing a failed deploy, if the cause is on the server itself.

## What to be honest about

Include a short, plainly-worded "Limits" section covering:

- **This is v1, written from the design.** It has not yet been proven over many Changes. Expect rough edges.
- A **successful API deploy has a gap of a few seconds** while the proven build replaces the running one. A failed deploy never reaches users, but a successful one is not yet seamless.
- **Enforced branch protection** may need a paid plan for private repositories. Without it, the merge gate is a habit rather than a rule.
- **Preview links**, for seeing a change before merging, are not built yet.
- Each new kind of Destination needs its own action added to the dispatcher before a repo using it can be onboarded.

## Structure to follow

1. **What this is** — three or four sentences, and who it suits.
2. **What you need before you start** — a GitHub account, a repo, somewhere to deploy, an AI coding tool that can run sessions against GitHub from a phone, a chat app for alerts.
3. **The everyday loop** — the seven steps, with the first diagram.
4. **What happens when a deploy fails** — with the second diagram.
5. **Onboarding a repository** — what gets added to a repo: AI-tool access, repo settings so the session has the right skills, a note in the repo's instructions file, small workflow files calling the shared ones, and the secrets. Say it is done from a Cloud session by pointing it at an onboarding document, and ends in a pull request.
6. **How it stays safe** — with the third diagram.
7. **Limits** — as above.
8. **A one-page checklist** — the daily loop as a numbered list someone can follow without re-reading the guide.

## Diagrams

Produce **exactly three**, each as an image **and** with its Mermaid source in a code block so it can be edited later. Keep them clean and readable on a phone screen: few boxes, short labels, one idea each.

1. **The loop.** Phone, then Cloud session, then pull request, then checks, then merge, then build on CI, then Candidate, then checks pass, then Cutover, then Live, with the Alert arriving back at the phone.
2. **When a deploy fails.** The same path up to the Candidate, then the check failing, the Candidate being discarded, the Live version continuing to serve users untouched, and an Alert reaching the phone.
3. **The locked deploy key.** A repository secret, then SSH to the server, then the dispatcher checking the request against its allowed list, then allowed actions proceeding and everything else refused. Show clearly that a leaked key cannot reach the rest of the server.

## Rules

- **Use placeholders**, never real addresses: yourapp.example.com, api.yourapp.example.com, SERVER_ADDRESS, your-org/your-repo.
- **Do not invent features.** If something is not described above, leave it out.
- Do not name specific commercial products as requirements where a category will do; describe the kind of tool needed, mentioning examples at most once.
- Use headings, short paragraphs and lists. No wall of text.
- End with the checklist, nothing after it.
