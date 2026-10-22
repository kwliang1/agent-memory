---
name: nova-has-no-treasury-gem
description: Nova doesn't consume treasury_prophet_api; it hand-writes zod schemas for treasury's Prophet API, so a contract change reaches nova at treasury deploy, with no gem bump
metadata:
  type: reference
---

Only venture pins the `treasury_prophet_api` gem. Nova (TypeScript) calls treasury over Prophet with `@angellist/prophet-js` and copies each response shape by hand as a zod schema in `graph/src/clients/treasury/operations/*.ts`, sent through `graph/src/clients/treasury/request.ts`.

**Why it matters:** a deploy plan once said nova would "pick up the gem bump". Kevin: "there is no gem in nova."

**How to apply:** for a treasury contract change that nova reads, plan the deploy order and the matching zod schema edit in nova. No pin protects nova, so a breaking change hits it as soon as treasury rolls out. The repo's `treasury-prophet-api` skill names only venture as a consumer.
