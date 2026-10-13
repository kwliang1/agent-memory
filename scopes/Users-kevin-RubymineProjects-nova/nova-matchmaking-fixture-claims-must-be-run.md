---
name: nova-matchmaking-fixture-claims-must-be-run
description: "Never hand Kevin a matchmaking test-fixture design from reasoning — 0-for-4 on reasoned claims vs 4-for-4 on executed ones in a single day. Run it and mutate it first."
metadata:
  type: feedback
---

**Hard rule, not a preference: a fixture claim about `graph/src/services/entityMatchmaking/`
(especially `commitLifecycle.test.ts`) does not go to Kevin until it has been run AND
mutation-checked.** Describing one from memory or from reading the code has a measured 0% hit rate.

**Why — the tally from 2026-09-26, one file, one day:**

Reasoned about, all wrong:
1. Four of six assertions in a new `recoverPortPlan.test.ts` had a leg that passed for the wrong
   reason (fixture gave the resolved and submitted owner the same email, so the assertion could not
   tell them apart; a three-way guard tested in one direction only).
2. `bindingsFor(rowId)` proposed as the rebuild-vs-bounce discriminator — vacuous. The binding key
   is `commit:${rowId}:${matchedIpseityEntityId}` (`commitRow.ts:50-51`), entity-derived, so a
   re-commit under the same owner mints the *same* key.
3. "Absence of a `needsReview` event" proposed as the replacement — also vacuous. A row that
   strands mid-`onEnter` emits no events at all, so it passes on the exact bug being fixed.
4. Invented venture user id `4242` in a fixture instead of the account's real `angellistId`, so
   nova and venture contradicted each other and the rebuild correctly refused as drifted.

Executed, all caught: every one of the above surfaced only by running the test.

**What actually discriminates rebuild-and-port from bounce-and-recommit:** count commit events.
`commitEventKey` is `commit:${rowId}:${attemptId}` (`commitRow.ts:53-54`) and *does* carry the
attempt, so a bounce mints a second event and finishing the dead commit does not:

```ts
expect((await rowOf(rowId)).status).toBe('COMMITTED');
expect(await prisma.fsmEvent.count({ where: { entityId: rowId, type: 'commit' } })).toBe(1);
```

Mutation-verified: deleting the `rebuildPortPlan` call yields `expected 2 to be 1`. See test 43y.

**How to apply:** if asked "what's the fixture?", either run it first or answer with the shape and
say explicitly it is unverified. [[feedback_verify_fixture_assumptions]] is the soft version of this
rule and it failed four times in one session, which is why this one is absolute.

**The same rule applies in reverse, to reviewers' "this test is redundant" findings (BANK-2191,
2026-09-30).** Two gate rounds in a row proposed deleting a test as over-testing, reasoning from
the assertion text. Both named load-bearing tests. Mutating `batchMetrics`' filter in
`app/src/components/views/AdminTools/EntityMigrationTab/helpers.ts` to drop its
`!('hideWhenEmpty' in metric && metric.hideWhenEmpty)` clause — so every zero-count card vanishes
rather than only Errored — turned **exactly two** tests red, and they were precisely the two the
reviewers had asked to delete (`labels every card`, `reports zero for a batch with no rows…`).
Every other test survived it.

**How to apply:** before accepting a redundancy finding, name the mutation the test supposedly
fails to catch and confirm no other test catches it either — by running it, with the Edit tool per
[[negative-check-toggles-use-edit]], and restoring after. Then tell the reviewer's successor round
the refutation, so it stops resurfacing. Deleting a test on a reviewer's say-so is the one gate
action with no safety net: nothing goes red when you get it wrong.
