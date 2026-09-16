---
name: graphql-variable-sanitizer-coverage
description: "How nova's GraphQL variable-log sanitizer (packages/logger yoga-plugin) redacts PII after BANK-1927: email is a substring deny + an allowlist for fields about emails; how to audit coverage (JSON scalars, stitched capital schema, template keys); what is still open."
metadata: 
  node_type: memory
  type: project
  originSessionId: 712a92b9-6176-4f20-9413-cc2b948ca7de
  modified: 2026-09-02T21:30:21.338Z
---

`packages/logger/src/yoga-plugin.ts` exports the one `Sanitizer` (deny substrings, exact keys, and — since BANK-1927 / PR #9851, 2026-09-02 — `allowedSubstrings`, checked first, exempting a key from every rule but still recursing into it) that redacts GraphQL `variableValues` before Datadog. Keys normalize lowercase with `\s _ -` stripped; **dots survive**. `email` is a deny *substring*, so every spelling (declared inputs, JSON-scalar keys, customer-template form keys like `pcEmail`/`authRepEmail2`) is hidden by default; the allowlist keeps the 11 real non-address inputs legible (`emailSubject`, `emailBody(JSON)`, `customEmail*`, `emailGreeting`, `emailMessage`, `emailStatuses`, `hasEmailed`, `receiveEmails`, `disableEmails`).

**Why this design:** Kevin's issue first proposed `email` as an exact key (like `tin`) to protect debugging output; the survey showed the address-key list is unbounded (templates mint keys) while the non-address list is bounded and code-defined, so the maintained list was flipped to an allowlist. Kevin chose this over exact-key when asked ("why not just always scrub based on email substring?").

**How to audit coverage (what each review round found):** (1) classify by enclosing pothos definition — `inputType`/`t.input.*`/`t.arg` are inputs, `simpleObject`/`prismaObject`/`t.expose*` are output and never in variables; (2) trace every `type: 'JSON'` input to its client builder (`activateRecipient.data`, `updateEntity.entitySettings`, `saveItem.data` incl. Vulcan reserved dotted keys in `packages/vulcan/schema/src/reservedKeys.ts`, admin `$settings` JSON via `packages/core/src/schema/settings.ts`); (3) **capital-api's schema is stitched into graph** (`graph/src/internal/schema/index.ts` + `graph/src/internal/capital/schema.ts`), so Meridian mutations sent under the `capital { … }` root field pass through graph's logger — include `capital-api/src` inputs; (4) test the exported `sanitizer`, not a copy, with one fixture key per allow entry so dropping an entry goes red.

**Still open (stated in PR #9851 "Not in this PR"):** names/postal addresses under template-defined DS form keys (`saveItem.data` → `saveReviewItem.context.txItemsData`, `genProcessPreviewPdf.itemsData`; `activateRecipient.transactionInput` / public `createTransaction.inputData`), plus `activateRecipient.data.displayName/ownerName`, `bulkCreateTransactions.data[].noticeName`, KYC `formData` names/nested addresses. Needs its own issue and a DS-owning reviewer; follow-up issue text was drafted but not filed (Kevin hadn't answered). See [[matchmaking-pii-scoring-architecture]].
