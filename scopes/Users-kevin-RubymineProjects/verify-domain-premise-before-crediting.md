---
name: verify-domain-premise-before-crediting
description: "Web-verify a domain/banking premise before crediting a critique or defending a design; don't reason only from the data model or a plausible-sounding claim."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 50416d87-5458-4308-87d5-9bae078f4ada
  modified: 2026-08-12T00:36:03.162Z
---

When an adversarial critique (or my own analysis) hinges on a **domain fact** (e.g. "US payees often use a different account number for ACH vs wire"), verify it with external research *before* crediting it or escalating it as a real issue — don't reason only from "the data model makes it representable" or from how plausible the claim sounds.

**Why:** On nova #9413 (inherit+lock transfer account), the review-critic claimed the lock breaks "split-account" payees. I credited it and escalated to Kevin as a real money-safety concern, reasoning from the fact that `bankDetails.ach.accountNumber` and `.wire.accountNumber` are independent fields. Kevin pushed back: "if it's a distinct account number, then it should be a new recipient. did you verify with external research?" I hadn't. Web search confirmed **a US bank account keeps the same account number across ACH and wire — only the routing number differs.** So the premise was false: a different account number = a genuinely different account = correctly a new recipient. The lock was right; I'd over-credited a plausible-but-wrong critique.

**How to apply:** Data-model representability ≠ real-world occurrence. For money/banking/legal domain claims, run a quick WebSearch and cite it before treating the claim as fact — whether it comes from a critic, a teammate, or my own hypothesis. Reinforces the global "every claim grounded in a verifiable fact; label hypotheticals" rule. See [[nova-3740-transfer-reroute]].
