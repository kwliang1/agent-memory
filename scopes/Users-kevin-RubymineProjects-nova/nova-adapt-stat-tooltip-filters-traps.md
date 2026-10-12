---
name: nova-adapt-stat-tooltip-filters-traps
description: "ADAPT Stat is the pressable metric card, but its selected halo dies inside a Card, Tooltip clobbers its onPress, and a controlled Filters loses the search debounce and the reviewer's added facets"
metadata:
  node_type: memory
  type: reference
  originSessionId: b4e9ff6f-7cee-44df-89fd-2e0c89916dbe
  modified: 2026-09-30T19:35:57.612Z
---

Learned building the LP-migration batch metric cards (BANK-2191, adapt 59.2.2). All three verified
against `app/node_modules/@angellist/adapt/dist/index.mjs` and by rendering.

**`Stat` with `onPress` IS the pressable metric card.** It renders as a `<button>`, and `isSelected`
drives a tinted halo. There is no separate pressable-card component — don't build one.

**You cannot box it.** The selected halo is a `::before` at `z-index:-1` with `inset: -space-100`
(`._1kzdglia` / `._1kzdgli3::before` in `dist/style.css`), so it paints *behind* the Stat. Any
`Card` wrapper's own background covers it and the selection becomes invisible — verified with
`panel`, `elevation='100'`, and `backgroundColor='transparent'`. Boxed cards and a visible selected
state are mutually exclusive.

**`Tooltip` silently replaces `onPress`.** It does
`cloneElement(children, mergeProps(buttonProps, triggerProps))`, so the child's press handler
becomes "open the tooltip" and the card stops filtering — with no type error and no warning. Use
**`Mouseover`** (`label` + `description`) instead: it wraps children in its own Box and leaves the
child's props alone.

**Don't pass `applied` to `Filters` just to sync chips after a programmatic filter.** Controlled
mode (`isControlled: !!appliedProp`):
- derives the VISIBLE facets from `applied`'s keys alone, so any facet the reviewer added by hand
  disappears, and a facet omitted from `applied` never renders up-front;
- drops the search box's 500ms debounce, putting a full client-side scan and a `network-only`
  refetch behind every keystroke;
- a controlled `search` key outlives its option when the CSV read fails, and adapt then
  `console.warn`s `[Filters] Missing option for applied key` on every render.

Instead **remount `Filters` with a computed `defaultApplied`** (`key={n}`, bumped only by the
programmatic action). A facet's chip label is seeded at mount and only updated by its own dropdown,
so the remount is what moves the chip. Two traps there: keying on the *selection* also remounts
mid-typing and costs the search box its focus per keystroke, and mirroring the live search value
into `defaultApplied` makes adapt's `isApplyingDefaults` true, which hides the Reset control and
makes Reset re-apply the search.

Related: [[nova-adapt-single-select-filter-unclearable]], [[nova-adapt-table-capabilities]].
