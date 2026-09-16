---
name: nova-bulk-upload-house-pattern
description: "nova's standard file-upload→parse pattern (Temporal filePostProcessing activity + lib/workbook.ts + nova-owned parseData, positional rows). nova DOES parse CSV/xlsx."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 54e023ad-2887-464c-895e-ba8313742df8
  modified: 2026-08-27T23:49:10.164Z
---

nova **does** have a CSV/XLSX parser — don't claim otherwise (I once wrongly did after grepping only one feature dir). The house pattern for bulk spreadsheet upload:

1. Client uploads the **raw file** → stored as an S3 `File` prisma row (`fileId`, with `metadata` linking the domain id, e.g. `{ distributionId }` / `{ bulkEntityUploadId }`). Fetched via `getFileFromBucket(s3, bucket, fileId)` (`lib/s3`).
2. A **Temporal `filePostProcessing` activity** parses server-side. Activities live in `graph/src/lib/temporal/activities/filePostProcessing/` — `processDistributionUpload.ts`, `processDirectoryEntityBulkEntityUpload.ts`, `processDirectoryEntityBulkFileUpload.ts`.
3. Parsing: `lib/workbook.ts` = `readWorkbook(bytes)` (xlsx `read`, `{type:'array'}`) → `getSheetData(workbook, sheetName)` (→ 2D array via `sheet_to_json({header:1, defval:''})`). Then a **nova-owned `parseData`** applies the column contract — e.g. `@angellist/nova-core/distribution/upload` (also exports `DISTRIBUTION_DATA_SHEET_NAME`, `MAX_DISTRIBUTION_UPLOAD_ROWS/BYTES`) and `@angellist/nova-core/directory/bulkUpload/entities`.
4. **Row identity is positional**: distribution uses `rowId: rowIdx + dataStartRow`; directory uses `rowId: i + 2` ("Excel rows 1-indexed, first row is header"). So parse-order = row id — deterministic, no client hash needed.
5. nova owns the fillable **template** too (`genEmptyBulkEntityTemplate`, `genTemplate.ts`, `genNovaEntities.ts`) — that's where the column contract is defined.

Libs: `xlsx` (SheetJS, pinned tgz) + `exceljs` in `graph/package.json`. Reports/exports also use `xlsx` `utils` widely.

Matchmaking-specific note: entity-matchmaking deliberately does NOT persist parsed PII (only ids + derived signals), and its ingest currently diverges from this pattern (client sends already-structured rows over GraphQL to `adminEntityMatchmakingStage`, plus a separate client-uploaded raw CSV to DocumentService via `reserveIngestFile`/BANK-1918). See [[matchmaking-pii-scoring-architecture]] for that flow and the BANK-1919 reference-passing refactor.
