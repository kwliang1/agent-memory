---
name: verify-localhost-e2e
description: Always verify localhost page loads end-to-end before sharing the URL with Kevin
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3f547bc3-7c80-4584-a0cd-1af36947d35d
---

Before giving Kevin a localhost URL to test, preverify that the page actually loads — hit it in the browser or at minimum exercise the GraphQL query against the seeded data to confirm no runtime errors.

**Why:** Tests and type checks pass but seed data can be incomplete (missing user records, missing active sub-accounts, nil associations), causing runtime errors on the actual page. Kevin hit "must be logged in" and "undefined method 'treasury_prime?' for nil" on seeded data that passed all specs.

**How to apply:** After seeding test data, use browser automation (chrome tools) or `curl`/`rails runner` to exercise the actual GraphQL query with the seeded run_uuid before reporting the URL. Verify the response has no errors.
