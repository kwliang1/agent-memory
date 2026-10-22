---
name: feedback_api_doc_audit_ignore_mock_examples
description: "In API doc-site audits, example values are mock; only flag doc claims that contradict behaviour, and verify subagent findings before relaying"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 8d0e0c9f-b22f-41d0-8ccb-4d5c43d1879b
  modified: 2026-10-22T05:53:49.429Z
---

When auditing nova's public REST docs (docs.nova.net, `graph/src/public/rest/docs-site/openapi.yaml`), example values are mock and out of scope. That covers error-example text and codes, IDs or cursors that don't decode, offset timestamps, and bank numbers. Flag only descriptions, enums, response codes and documented routes or fields that contradict the code.

**Why:** 2026-10-22 Ark API audit. Kevin had me remove flags twice: "remove any flags based on mock values" and "these are still mock value flags. irrelevant for a doc site". He also pushed back with "are you *certain*?" on a subagent's overstated Q1 claim that I had relayed without reading the code.

**How to apply:** brief audit agents to skip example values. Read the code myself before relaying any subagent verdict to Kevin. Plain doc inaccuracies go in one docs PR; file a Linear issue (in project P-NIS-1576, Transactions API V1) only where Kevin asks or where behaviour is wrong.
