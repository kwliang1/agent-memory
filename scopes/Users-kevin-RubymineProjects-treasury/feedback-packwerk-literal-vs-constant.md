---
name: feedback-packwerk-literal-vs-constant
description: A review nit to swap a string literal for a cross-package constant ref can break Packwerk strict mode — verify before adopting
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1fabef2d-93af-456e-8e76-9773c2e3aa6f
  modified: 2026-08-03T22:27:53.503Z
---

On treasury PR #8211 a reviewer (dcetlin) suggested replacing the literal `'DIBS::IncomingPayment'` in `BalanceCheck::Record::CONFIRMED_CREDIT_RECORD_TYPES` with the "facade" reference `DIBS::IncomingPayment.name`. I adopted it — and it hard-failed CI on `packwerk-treasury`: `balance_check` (root `.` package) referencing `::DIBS::IncomingPayment` (in `backend/dibs`) is a dependency violation under **Packwerk strict mode**. The string literal was *intentional* package decoupling. Reverted to the literal + a comment saying why it must stay one.

Also: the persisted `record_type` value is `DIBS::IncomingPayment.name` == the string `"DIBS::IncomingPayment"` (NOT `DIBSApi::IncomingPayment` — that class doesn't exist; `DIBSApi::IncomingPaymentsService` is the service). The constant must match that exact string.

**Why:** a class name embedded as a string literal is not the same as referencing the class — the literal costs nothing at the package boundary; the constant reference pulls in a cross-package dependency that strict-mode packages forbid. AI/human review nits that say "don't hardcode, reference the constant/facade" can be actively wrong across a Packwerk boundary.

**How to apply:** before swapping a string literal for a constant/class reference on a review nit, run `bin/packwerk check <file>` locally. If the referenced constant lives in another package (esp. `backend/*`) and the current package is strict, keep the literal and comment the reason. Run packwerk on any diff that adds a new constant reference before pushing. Related: [[feedback-question-the-shared-constant-premise]] (Packwerk blocking a read often means the concept belongs on one side).
