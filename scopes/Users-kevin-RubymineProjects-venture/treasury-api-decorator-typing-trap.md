---
name: treasury-api-decorator-typing-trap
description: TreasuryAPI resource calls return Protip::Decorator, not the proto message — typed sigs on them report TypeErrors in prod
metadata:
  type: reference
---

`TreasuryAPI::CustomerAccount.wire_info` (and other protip resource calls) return a `Protip::Decorator`, not `TreasuryAPI::Messages::*::Output`. A sig typed as the message passes specs (doubles, and tests ignore sig errors) but `config/sorbet.rb` reports every mismatch to ErrorTracker in prod. Type them `T.untyped`, like `Treasury::CustomerAccountWireInfoFinder`. Protobuf repeated fields are not Arrays: use `T::Enumerable`.

Also learned on the same change:
- `ManagementCompany` has no `id`, so Apollo leaves it unnormalized. Return the `ManagementCompanyBankAccount` (which has an `id`) from mutations so the cache updates.
- CI runs `bin/ci/rubocop_new_files.sh` separately; new files must be `typed: strict`. `rubocop_changed_files` alone misses it.
- Nested non-null fields (e.g. `Types::Invest::WireInfoType` → bank/beneficiary) null-bubble at serialization, past any resolver rescue, and fail the whole query under Apollo's default errorPolicy.
- Network failures raise `Faraday::Error`, not `Protip::Error`. Rescue both.
