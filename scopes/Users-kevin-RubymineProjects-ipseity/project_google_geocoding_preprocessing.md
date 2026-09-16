---
name: ISOBIC free-text defeats Google geocoder; pre-processing needed
description: BANK-1296 pre-flight confirmed that raw ISOBIC address strings produce ~60% no_match (city+postal_code bucket) via Google Geocoding. Root causes: InfoService Latin-1 strip, and ISOBIC's unpunctuated free-text format defeating Google's NLP parser. BANK-1274 needs a country-aware pre-processing layer.
type: project
originSessionId: 3671a678-85e7-40db-a1f7-1a2a37316e45
---
BANK-1296 pre-flight (2026-04-23, PR #1417) validated the Google-geocode-at-import approach on 2,000 distinct ISOBIC addresses. Result: **60% no_match, 9% fuzzy, 31% exact (city+postal_code bucket).** Too poor to ship as-is.

**Why:** Feeding raw ISOBIC free-text to Google's `geocoding_api` endpoint fails in two ways:

1. **Latin-1 diacritic strip** in `lib/integrations/google/info_service.rb:46` — `gsub(/[-ÿ]/, '')` deletes ö/ä/ü/ß/é/è/ñ BEFORE the Google call. "Müllerstraße" → "Mllerstrae". Affects DE (88% non-exact), LU, ZA, parts of ES/FR. **This is a production bug in live Ipseity address RPCs too, not just this script.** File as a standalone fix.

2. **ISOBIC free-text format defeats Google's NLP parser** even for ASCII-only countries. Sample UK row: `AFFINITURE CARDS LIMITED FLOOR FIRST 8 WILKINSON COURT WILKINSON BUSINESS PARK WREXHAM WREXHAM LL13 9AE UNITED KINGDOM` → Google returns `locality|political` (Wrexham), `partial_match: true`, drops the postcode completely. The postcode is in the source string. Query with just `LL13 9AE UK` and Google returns `types: ["postal_code"]` with a populated `postal_code` field. GB is 86% non-exact on raw ISOBIC, essentially 0% on stripped-to-postcode. Similar for US (70% non-exact raw).

**Why:** Google Geocoding is an NLP geocoder, not a structured parser. Company-name prefixes ("COMPANY LTD FLOOR FIRST"), doubled city tokens ("WREXHAM WREXHAM"), missing punctuation — all confuse the matcher. Google latches onto the most confident entity (usually the city) and returns a `partial_match` at that level, discarding downstream tokens including the postcode.

**How to apply** (for BANK-1274 ImportService design):

- Do NOT pass raw ISOBIC free-text to Google directly.
- Build a country-aware pre-processing layer:
  1. Country-specific postcode regex extractors (UK: `[A-Z]{1,2}[0-9][A-Z0-9]? [0-9][A-Z]{2}`; DE/FR/IT: `\d{5}` or `\d{4,5}`; US: `\d{5}(-\d{4})?`; etc.).
  2. Progressive-fallback query: try full address → on `partial_match: true` with missing postal_code, retry with `<postcode> <country>` → on still-bad, `IncompleteBranch`.
- Fix the Latin-1 strip before anything else.
- IT/NL/BE/FR geocode cleanly on raw input; country-specific pre-processing is most valuable for DE/UK/US/CN/AE/LU.

**Do not re-run the full 73K batch on raw input** — results would be the same ~60% garbage.
