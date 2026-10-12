---
name: nova-adapt-single-select-filter-unclearable
description: "ADAPT: a single-select Filters facet listed in defaultApplied cannot be cleared — Reset passes a falsy key that the onChange wrapper swallows"
metadata:
  node_type: memory
  type: project
  originSessionId: fb2c3e87-3f79-4685-8cab-fd7094f08e48
  modified: 2026-09-29T17:54:36.421Z
---

In ADAPT 59.2.2 (`app/node_modules/@angellist/adapt/dist/index.mjs`), a `selectionMode: 'single'`
facet that appears in `<Filters defaultApplied>` has **no working clear path**:

- a key in `defaultApplied` ⇒ `isDefaultFilter: true` ⇒ `isRemovable: !isDefaultFilter` = false, so
  the chip shows **Reset**, not Remove;
- `useVisibleFilter.handleReset` calls `onChange(defaultValueProp)`, which is `undefined`;
- `SingleSelectionFilter`'s wrapper opens with `if (!newKey) { return; }` — swallowed.

Net: the chip clears visually while the query keeps filtering. `onAppliedChange` never fires.
Multi-select facets escape this because their reset value is `[]`, not `undefined` — which is why
`match`/`port` can sit in `defaultApplied` safely and a single-select one cannot.

**Two fixes, both verified by rendering real adapt in RTL:** omit the facet from `defaultApplied`
(it gains a Remove button that does fire `onAppliedChange`; cost is it sits under "Add filter"), or
give it an explicit "Any" item as the default key so the reset value is truthy.

Found on BANK-2122 (PR #10576) after switching a facet from multi- to single-select — the
default-applied placement had been correct while it was multi-select, so this is a trap that only
appears when you change `selectionMode`. Verify by rendering, not by reading the bundle:
`isRemovable`/`isResettable` are near each other and easy to misread. See
[[nova-adapt-table-capabilities]].
