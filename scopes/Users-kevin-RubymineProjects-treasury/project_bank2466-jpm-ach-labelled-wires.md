---
name: project_bank2466-jpm-ach-labelled-wires
description: JPM sometimes sends Fedwire credits as type ACH, stranding the matching Transfer; repair runbook (patch type to WIRE, reset the workflow). The code fallback (#9315) was closed.
metadata:
  type: reference
---
JPM DIBS webhooks have reported Fedwire credits as `type: ACH` (INC-5857, 10/29 and 10/30), stranding funds-migration Transfers waiting on a wire.

**Repair:** patch the webhook event's `resourceObject.type` to `WIRE`, keep `typeReportedByJpm: ACH`, then let the Temporal retry complete it or reset the workflow. A JPM replay after the repair can't double-credit (unique `(imad, leg)` on `dibs_wire_metadata`), but the replay workflow retries forever, so terminate it.

**Why no code fix:** Kevin closed #9315 (fall back from an untraced ACH-labelled credit to a same-amount pending wire). Bugbot's objection was that an untraced real ACH could complete an unrelated same-amount wire, and Kevin treats the mislabel as JPM's bug to fix. The code is still on the local branch `kevinliang/bank-2466`.
