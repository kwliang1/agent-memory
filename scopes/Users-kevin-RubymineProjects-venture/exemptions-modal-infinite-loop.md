# ExemptionsModal Infinite Loop Investigation

## Status: Fix v1 deployed but didn't resolve the issue. Fix v2 in progress.

## PR
- https://app.graphite.com/github/pr/angellist/venture/26688
- Branch: `frontend/fundraising/components/UpsertIpseityEntityModal/Shared/ExemptionsModal/index.tsx`

## Production repro entity
```
InvestmentEntity id: 370521
slug: sapphire-emerging-venture-managers-vii-lp-firm
entity_type: firm, is_fund: true
treasury_account_id: nil
cached_kyc_data_complete: true
entity_api_id: 019ce83446d87151926f359627804278
invest_account_id: 1000079
```

## File
`frontend/fundraising/components/UpsertIpseityEntityModal/Shared/ExemptionsModal/index.tsx`

## Fix v1 (deployed, insufficient)
- Replaced `form.watch('exemptionCategory')` with `useWatch({ control: form.control, name: 'exemptionCategory' })`
- Added ref guard on `useEffect` to prevent `setValue` on mount
- This was NOT enough to break the loop

## Root cause analysis (deeper)
The cascade has multiple drivers, not just `watch`:

### 1. `formState: { isSubmitting }` destructuring (lines 60-63)
Even with RHF v7's Proxy, this subscribes ExemptionsModal to formState notifications.

### 2. FormError inside adapt-react-hook-form's FormModalContent
`FormError` (in `@angellist/adapt-react-hook-form` dist):
- Subscribes to `formState.errors` via `useFormContext()`
- Calls `register('__formLevelError__')` on EVERY render
- This `register` call may trigger form state notifications
- FormError is rendered UNSUPPRESSED inside FormModalContent (line 3975 of dist/index.mjs)

### 3. The cascade (even with useWatch fix)
1. Category selected -> revalidation -> `errors` change -> `FormError` re-renders
2. `FormError` calls `register('__formLevelError__')` -> form state notification
3. ExemptionsModal re-renders (formState subscription from `isSubmitting` proxy)
4. New header buttons array -> FormModal re-renders -> `FormError` re-renders -> goto 2

### 4. useEffect with setValue still contributes
`setValue('exemptionDescription', undefined)` in useEffect can trigger revalidation
when form is in revalidation mode (post `form.trigger()` from `isFixingIncompletePages`)

## Fix v2 (in progress, not yet committed)
Three changes to completely break the cascade:

### Change 1: Remove `formState: { isSubmitting }` destructuring
Eliminates ExemptionsModal's formState proxy subscription entirely.

### Change 2: Remove `useEffect` + `setValue` entirely
Move description reset to "Next" button's `onPress` handler (event-driven, not render-driven).
Use a ref to track which category was last used for the description step.

### Change 3: Clean stale descriptions in handleSubmit
For edge case where user switches from description-requiring to non-requiring category:
```tsx
if (!requiresDescription(values.exemptionCategory)) {
  values.exemptionDescription = undefined;
}
```

### Concrete changes needed:
- Import: remove `useEffect`, keep `useRef` and `useWatch`
- Remove `formState: { isSubmitting }` from destructuring (just get `setValue` or use `form.setValue`)
- Remove the entire `useEffect` block
- Add `descriptionCategoryRef` ref
- In "Next" button onPress: reset description if category changed, then goToNextStep
- In "Add exemption" button: remove `isSubmitting` from isDisabled/isLoading
  (FormModal's internal Button component already handles isSubmitting for submit buttons)
  BUT NOTE: `...y` spread in Ma component OVERRIDES internal isDisabled, so we need
  to NOT pass isDisabled at all (or only pass the category check without isSubmitting)
- In "Back" button: remove `isDisabled: isSubmitting`
- In handleSubmit: clear description for non-requiring categories before submitting

### IMPORTANT caveat about FormModal Button internals
In adapt-react-hook-form's Button (Ma) component:
```js
const A = y.type === "submit" && isSubmitting;
return M.createElement(O_, { isDisabled: A, isLoading: A, ...y, ref: f });
```
The `...y` spread OVERRIDES internal isDisabled/isLoading. So if we pass
`isDisabled: exemptionCategory === undefined`, it overrides the internal
isSubmitting check too. We should either:
- Not pass isDisabled at all for submit buttons (loses the "must select category" check)
- OR keep `isDisabled: exemptionCategory === undefined` and accept that the button
  won't show loading state during submission (submission is brief)

## Key files
- `frontend/fundraising/components/UpsertIpseityEntityModal/Shared/ExemptionsModal/index.tsx` - THE file
- `frontend/fundraising/components/UpsertIpseityEntityModal/Shared/ExemptionsModal/helper.tsx` - validation schema, requiresDescription
- `frontend/fundraising/components/UpsertIpseityEntityModal/Shared/ExemptionsModal/ExemptionCategory/index.tsx` - SelectList (clean, no issues)
- `frontend/fundraising/components/UpsertIpseityEntityModal/Shared/ExemptionsModal/ExemptionDescription/index.tsx` - uses `watch` from useFormContext (only rendered on step 2)
- `frontend/fundraising/components/UpsertIpseityEntityModal/Shared/hooks.ts` - useUpsertIpseityEntityForm, form.trigger() on mount
- `frontend/fundraising/components/Adapt/MultiStepFlow/context.tsx` - useMultiStepFlow hook
- `frontend/fundraising/node_modules/.pnpm/@angellist+adapt-react-hook-form@12.3.48_.../dist/index.mjs` - FormModal, FormError, Button internals

## Testing
- TypeScript: `cd frontend/fundraising && npx tsc --noEmit`
- Tests: `cd frontend/fundraising && pnpm test -- --testPathPattern="UpsertIpseityEntityModal"`
- Local repro needs entity with isFixingIncompletePages=true (hard to find locally)
- The user rejected edit for the buttons section — need to re-apply carefully
