# Why latest upstream main?

This project builds the **Desktop shell only** and points it at a **remote agent**.

- The shell’s job is UI, WebSocket/HTTP to `/api/*`, and local OS affordances.
- The agent’s job (tools, memory, models, messaging) lives on the remote host.

Tracking **`origin/main`** means you get Desktop fixes as soon as Nous merges them,
without waiting for a remote-host update cycle.

Keep the remote host updated on its own schedule (`hermes update`). If Desktop
and remote drift too far and something breaks, either:

1. Update the remote host, or
2. Temporarily set `HERMES_AGENT_REF=<good-sha>` and rebuild.
