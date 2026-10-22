---
name: nova-has-no-treasury-gem
description: Nova doesn't consume treasury_prophet_api; it hand-writes zod schemas for treasury's Prophet API, so a contract change reaches nova at treasury deploy, with no gem bump
metadata:
  type: reference
---

Only venture pins the `treasury_prophet_api` gem. Nova (TypeScript) calls treasury over Prophet with `@angellist/prophet-js` and copies each response shape by hand as a zod schema in `graph/src/clients/treasury/operations/*.ts` (e.g. `achPull.ts`). Calls go through `graph/src/clients/treasury/request.ts`. Verified on nova origin/main, 2026-10-22.

**Why it matters:** on 2026-10-15 (06e944fe) a deploy plan said "Nova ships after it picks up the gem bump". Kevin: "this is incorrect. there is no gem in nova. Is the treasury change breaking for nova? they'll need to come in quick succession?"

**How to apply:** for a treasury contract change that nova reads, plan the deploy order and the matching zod schema edit in nova. There is no pin to protect nova, so a breaking change hits it as soon as treasury rolls out. The repo's `treasury-prophet-api` skill only names venture as a consumer.
