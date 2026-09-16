---
name: treasury-packwerk-dibs
description: "Treasury packwerk: root can't reference DIBS models directly — go through app/public_api/dibs_api facade; app/tasks/maintenance is packwerk-excluded"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 44bb6bfd-0226-4aa0-9869-657ad1d53a41
---

Treasury's root package (`package.yml`, `enforce_dependencies: strict`) does NOT depend on `backend/dibs` — referencing `DIBS::*` models from `app/services`, `app/models`, etc. fails CI's packwerk step. The sanctioned chain is root → `app/public_api/dibs_api` (facade services like `DIBSApi::PaymentTransfersService`) → `backend/dibs`.

**Why:** BANK-1582's guard referenced `DIBS::IncomingPayment` from `app/services/incoming_wires/state_service.rb` and CI failed; local `bin/packwerk check` only works inside the app container (crashes on host env).

**How to apply:** add/extend a `DIBSApi::*Service` in `app/public_api/dibs_api/` for any root-package read/write of DIBS data. Note `app/tasks/maintenance/**/*` is excluded in `packwerk.yml`, so maintenance tasks may reference DIBS models directly. Related: [[venture-packwerk-boundaries]].
