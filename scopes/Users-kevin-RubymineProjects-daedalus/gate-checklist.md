# daedalus gate checklist (no CI exists)
- `bun test` — all pass
- `bunx tsc --noEmit` — clean
- `bun src/cli.ts ingest` on real logs — `failed: []`
- `bun src/cli.ts check-rounds` — sampled rounds match findings files
- `git cat-file -p HEAD | grep gpgsig` — commit signed
