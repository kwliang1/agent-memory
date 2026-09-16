---
name: treasury-countries-enum-binread-flake
description: "FIXED and MERGED to main 2026-07-31 (PR #8405 / BANK-1726, commit 66cdbe6ad) — the Tempfile fixture pattern that replaced the global File.binread stubs, and why flush beats rewind"
metadata:
  node_type: memory
  type: project
  originSessionId: f47c16b3-3921-4f56-973d-9f74cd90f794
  modified: 2026-08-01T03:56:24.400Z
---

**MERGED to main 2026-07-31 22:12 UTC** (PR #8405 / BANK-1726, merge commit `66cdbe6ad`). Verified: `git show origin/main:spec/graphql/mutations/customer_accounts/create_on_core_account_spec.rb | grep -c "expect(File).to receive(:binread)"` → **0**. The flake is dead on main; a red `JSON::ParserError` shard now means something new, not this.

Keep the habit anyway — **when adding an example to a spec that stubs `File.binread`, don't copy the stub.** Reaching a code path that skips `File.binread` (e.g. file-less GraphQL input when the assertion doesn't need the upload) sidesteps the whole class of problem. Done that way in PR #8408.

**Root cause:** an unconstrained `expect(File).to receive(:binread).and_return('test')` is picked up by *anything* lazily autoloaded during the example. `GraphqlSchema.execute` autoloads `Types::CountriesEnum`, whose class body iterates `ISO3166::Country.countries` at load time (`app/graphql/types/countries_enum.rb:5`), so the countries gem parsed `'test'` as its JSON data cache. `config/environments/test.rb` sets `eager_load = false`, so CI autoloads lazily too — a real CI hazard, not a local artifact.

**Scope was 2 live flakes, not 1.** The issue named only `create_on_core_account_spec`, but `alloy_upload_document_spec` failed identically at `--seed 1`; `all_statements_resolver_spec` was a latent third. Lesson: `grep -rnE "(allow|expect)\(File\)" spec/` before scoping a stub-poisoning fix — don't trust the issue's file list.

**Arg-constraining is NOT a fix.** `expect(File).to receive(:binread).with('test')` merely converts the error into `received :binread with unexpected arguments`. Needs an `and_call_original` fallthrough, or no stub at all.

**The pattern that replaced it** (now the only idiom for this; zero global `File` stubs remain repo-wide):
```ruby
let(:file_contents) { 'test'.b }   # binread returns ASCII-8BIT; .b keeps matchers encoding-correct
let(:tempfile) do
  Tempfile.new('upload').tap do |f|
    f.binmode
    f.write(file_contents)
    f.flush # not rewind — EOF makes a handle-read regression fail loudly
  end
end
let(:file) do
  ApolloUploadServer::Wrappers::UploadedFile.new(
    ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: file_name),
  )
end
after { tempfile.close! }
```
`ApolloUploadServer::Wrappers::UploadedFile` is a `DelegateClass(ActionDispatch::Http::UploadedFile)`; only `:tempfile` is required (`:type`/`:head` optional). No `require 'tempfile'` needed — transitive from `rails_helper`.

**`flush` vs `rewind` — the non-obvious bit.** Verified on ruby 3.4.8: with neither, `File.binread(path)` returns `""` (silently empty fixture). `rewind` flushes *and* seeks to 0, leaving the fixture readable from the handle — so a regression doing `obj.read` instead of `File.binread(obj.path)` silently passes. `flush` leaves the handle at EOF, so that regression returns `""` and fails. Proven by sabotaging the resolver and watching the spec go red.

**Still armed:** `Types::CountriesEnum` iterates at class-body load time, so the trap returns if anyone adds a global `File` stub to a spec that is first to touch `GraphqlSchema.execute`. Unfiled option: warm the gem cache from `rails_helper` (global test-boot side effect — Kevin's call).

Related: [[treasury-spec-tasks-maintenance-flake]], [[treasury-outgoing-transfers-resolver-flake]], [[treasury-worktree-dev-loop]].
