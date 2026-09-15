# Claude Code cloud sessions are the delivery path; ai-agents is not

Mobile Delivery turns requests into pull requests through Claude Code Cloud sessions, not through the Telegram-driven Designer/Coder/Reviewer agents in `ethichadebe/ai-agents`. Those agents were built to simulate this workflow, not to run alongside it, and two agents opening, reviewing and merging pull requests on the same repositories would contend with each other. The Cloud sessions are already paid for through the Claude subscription and are the path that has been proven end to end.

## Consequences

The ai-agents orchestrator must not keep write or merge access to any Onboarded repo, even though its code stays as a reference.
