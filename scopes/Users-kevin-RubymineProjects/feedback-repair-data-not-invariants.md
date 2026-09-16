---
name: feedback-repair-data-not-invariants
description: "When a state is anomalous, repair the data — don't add a code branch that weakens the state's invariant to accommodate it"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f523bd46-f46b-441f-a99c-4a3ab16700de
  modified: 2026-07-31T21:15:06.080Z
---

If production rows are in a state that "shouldn't be possible," **fix the rows**, not the state machine.

**The mistake (PR #8416, treasury):** IncomingWires 312743/312744 sat in `pending_return` with `return_transfer = nil`. `IncomingWires::StateService#return!` raises for that combination, which blocked returning them. I added a `return!` branch for it. Reviewer harsohailB rejected it: `pending_return` *means* a cross-bank return transfer is in flight, so `return_transfer.present?` is a genuine invariant of that state. Those wires were never assigned and never had a forwarding transfer, so **`provisioned` was their correct state all along** — and `return!`'s existing `provisioned?` branch already did everything needed. I'd weakened a real invariant to accommodate two corrupt rows.

**Why:** I treated the observed state as ground truth and reasoned forward from it. I also talked myself out of the repair with a bad objection — "there's no legal `pending_return → provisioned` transition." A one-off data repair is not a state transition; it's asserting the state was wrong to begin with. My own spec did that exact `update!(state:)` in the other direction.

**How to apply:** when a code change exists only to accommodate a specific bad row, stop and ask whether the row is wrong. Check the invariant: find every writer of the state (grep `transition_to!(State::X)`) — if the accompanying field is written at exactly one site right beside it and never cleared, the combination is unreachable by design, so the row got there by manual DB write. Repair it in the one-off script, guarded on every precondition, in the same session as the rest of the operation so there's no window where the repaired row is exposed to other flows. Keep any spec that covers the *existing* branch you're now relying on — it may have had none.

Also: 10 review rounds of mine never questioned the premise, because I fed every reviewer the state as a given. State assumptions as assumptions in review prompts. Related: [[feedback-question-the-shared-constant-premise]], [[feedback-check-human-pr-reviews]], [[bai2-458-rtp-debit]].
