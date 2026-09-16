---
name: bridge-only-delivers-dm
description: "The bridge only DELIVERS the DM (chat_id D0BE3RB4Y00) to me as inbound messages. Other Slack channels are readable on-demand via fetch_messages (bot is a member) but route to mappedSession=none — not pushed to me, and Kevin can't invoke me from them."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0e543ade-488f-42be-95ee-8849ec3b5a75
---

I (main/spawned sessions) only receive inbound messages from the **DM `D0BE3RB4Y00`**. Messages in other Slack channels (e.g. incident channels `C0BK…`, `C045…`) reach the daemon's router but map to **`mappedSession=none`** — they are NOT delivered to any session. So **Kevin cannot invoke me by posting in another channel** (even @-mentioning the bot `senna`); the bot merely being a channel member doesn't wire routing.

BUT I **can READ any channel on demand** via `fetch_messages(channel="C…")` since `senna` is a member — verified 2026-07-24 reading a P0 incident thread in `C0BKKP8G2KU`. So when Kevin links a message in another channel and asks "did you see this?", the answer is: not automatically, but I can fetch + read it.

To enable cross-channel *invocation* would be a hydra feature: an @-mention router in `daemon/router.ts` (which already sees those events and currently drops them as `mappedSession=none`) that spawns/binds a session to the mentioned thread. Not built yet — offered to Kevin 2026-07-24.