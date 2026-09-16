---
name: payment-trace-identifiers-two-stores
description: "Wire IMAD/OMAD and ACH trace numbers live in TWO treasury stores; the Treasury-side column is a lossy mirror, and the retired SVB rail wrote a different format into it"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 8fd804ba-bcab-4f77-adeb-d769f4b515da
  modified: 2026-07-28T05:14:12.347Z
---

Verified against treasury prod 2026-07-27 while building BANK-1506.

**Every payment tracing identifier has two stores.** The Treasury-side column is written directly on the Treasury Prime rail, but for DIBS-executed payments it is only mirrored back when a completion notification arrives — so it is routinely empty for a payment DIBS already has an identifier for.

| | Treasury-side coverage |
|---|---|
| DIBS-rail wires (90d) with nil `outgoing_wires_metadata.imad` that DO have one in `DIBS::WireMetadata` | **129/140 (92.1%)** |
| `AchPush.partner_bank_trace_number`, TP rail (60d) | 96.9% |
| `AchPush.partner_bank_trace_number`, **DIBS rail** (60d) | **0.0%** |
| `AchPull.partner_bank_trace_number`, **DIBS rail** (60d) | **0.9%** |

DIBS is already the larger rail for pulls. **Reading only the Treasury column ships a mostly-empty feature.** Fall back to the DIBS adapter via `DIBSApi::PaymentTransfersService` (which now exposes `wire_trace` / `ach_trace_number`, added in treasury #8375 — they narrow the polymorphic metadata internally so `app/services` never names a `DIBS::` constant; naming one there is a **packwerk violation** and `bin/packwerk check` is a Buildkite gate).

**Format trap:** `partner_bank_trace_number` holds two incompatible formats. A real Nacha trace is 15 digits (8-digit ODFI + 7-digit sequence), but the retired SVB rail wrote only its own **7-digit internal sequence** (`Svb::ConfirmationAchFile` → `rjust(TraceNumber::LENGTH, '0')`). Distribution: AchPush `{7 => 36,971, 15 => 6,030}`, AchPull `{7 => 360,956, 15 => 7,202}` — every 7-digit row predates 2023-03-18 and a 200-row sample is 100% SVB. A bank cannot look up a 7-digit value; filter to `/\A\d{15}\z/`.

**OMAD is ~absent** (2.4% of wires 12mo, ramping). **UETR is Increase-only** (0/140 on the gap set, 1.7% sampled) — not worth exposing.

Also: `SubmittableAch#trace_number` is an unrelated AngelList-internal `TraceNumber` record that is **created on read**. Never call it from a read path; read the `partner_bank_trace_number` column.

Related: [[ivc-phantom-overcredit-migration]], [[bai2-ach-debit-attribution]].
