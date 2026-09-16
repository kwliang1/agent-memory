---
name: nova-adapt-table-capabilities
description: ADAPT Table has NO expandable rows; client-side table-in-a-blade and client-side Filters both have working nova precedents
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0175bc4e-ff44-4eb8-b247-0f15f49ed620
  modified: 2026-09-10T20:49:52.116Z
---

ADAPT's `Table` (`@angellist/adapt`) has **no expandable/nested row support**. Grepping the whole
`node_modules/@angellist/adapt/dist/types/components/Table/` tree turns up `expand` only as
internal `aria-expanded` on header/group views. Any design that needs per-row detail must use
`kind: 'custom'` + `cells/CellPopover`, flatten the detail into columns, or use
`groupBy`/`renderGroupHeader` (`Table/groups.d.ts`). This is the deciding cost when converting an
`Accordion` card list into a table.

What Table *does* support: cell kinds `button`, `tag`, `custom`, `text`, `money`, `date`, `menu`,
`overflowMenu`, `copy`, `editable`, `progress`, `sparkline` (`Table/types.d.ts:129-164`);
`useTable` accepts static client-side `items` plus optional `filter`/`sort` fns
(`Table/hooks/useTable.d.ts`).

Working precedents in `nova/app/src` (verified 2026-09-10):
- **Table inside a blade section, static items:** `components/views/Distribution/PipelineTab/DraftPaymentBlade/ContactsSection.tsx:70` — `useTable({ items, columns, size: 'compact' })`, items rebuilt inline each render (so async-arriving columns re-sync for free, no memo needed).
- **Client-side filter chips:** `components/views/Settings/DigitalSubscriptions/LandingPage/TemplatesTable.tsx:169` — `<Filters options={...} onAppliedChange={(applied) => table.filter(applied)} />`.

Contrast with the server-driven path: `useQueryResultTable` from `@angellist/adapt-apollo`
(`EntityMigrationTab/RowsTable/useEntityMigrationRowsTable.ts`) — cursor paging plus
`filterVariablesTransform`. None of that machinery transfers to a nested array already embedded in
a parent payload. See [[nova-lp-porting-review-tab]].
