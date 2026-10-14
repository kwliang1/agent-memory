---
name: treasury-single-value-tenum-and-struct-sigs
description: "Treasury rubocop rejects a single-value T::Enum (Sorbet/MultipleTEnumValues, no disable precedent); use a DataChangeRequest::CATEGORIES-style string constant list with T.let. A class-method sig inside a T::Struct returns T.attached_class, not the bare class name."
metadata:
  type: reference
---

Two Sorbet/rubocop traps hit on PR #9156 (2026-10-14):

- `Sorbet/MultipleTEnumValues` flags a T::Enum with one value and nothing in the repo disables it. For a one-value code set, mirror `DataChangeRequest::CATEGORIES`: `FOO = 'FOO'` then `CODES = T.let([FOO].freeze, T::Array[String])` (strict files need the `T.let`). A GraphQL enum can iterate `CODES` directly.
- In a `# typed: strict` `T::Struct`, a `class << self` builder's sig must say `returns(T.nilable(T.attached_class))`; `returns(T.nilable(PreSubmissionError))` raises `NameError: uninitialized constant #<Class:…>::PreSubmissionError` at load because the singleton class does not resolve the bare name.
- New GraphQL object types need a tapioca DSL RBI (`bin/tapioca dsl Types::…`); enums do not. `bin/ci/ensure_sorbet_in_sync` cannot run in the app container (`dockerize` missing), so run `bin/tapioca dsl --verify` directly. See [[srb-tc-is-not-the-sorbet-ci-step]].
