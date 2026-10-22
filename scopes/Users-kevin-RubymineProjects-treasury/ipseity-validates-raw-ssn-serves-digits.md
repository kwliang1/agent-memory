---
name: ipseity-validates-raw-ssn-serves-digits
description: ipseity validate_tax_id checks the SSN as stored, but EntityAPI serves treasury a digits-only copy — emulate old treasury checks on the stripped value
metadata:
  type: reference
---

ipseity `IdentityData::Person` serializes `ssn&.gsub(/[^0-9]/, '')` (person.rb:139,172), but `Validation::TaxIdService` validates the raw stored string. "123 45 6789" or EIN-shaped "NN-NNNNNNN" in an SSN field fail ipseity while treasury sees a clean 9-digit value. When comparing treasury-side logic to ipseity in a prod console, feed the old logic the stripped value — BANK-2280's first count (51) was wrong for this reason; the real count was 237 (42 format-only).

**How to apply:** any prod "old vs new" TIN comparison run in the ipseity console must strip non-digits before applying treasury-side rules. Kevin chose (2026-10-19) not to normalize in ipseity; format-only SSNs are a data-cleanup list. See [[treasury-prod-console-access]].
