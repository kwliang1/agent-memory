---
name: feedback-design-review-in-pointy
description: Put design docs Kevin must review in a reviewable doc (Claude Docs; pointy when its auth works) and send the link; never a local .md path
metadata:
  type: feedback
---

When a design is ready for Kevin's review, publish it as a pointy doc (`mcp__pointy__create_doc` + `append_doc`; URL `https://huge.pointy.ink/docs/<id>`) and send that link. Local files under ~/.claude/review-findings stay the working copies.

**Why:** 10-18 on daedalus V8, I sent "Doc: ~/.claude/review-findings/.../design_v3.md"; Kevin: "What? I want to review here. Why not pointy". He reviews from Slack/phone and comments in the doc. Minutes later pointy had an auth issue for him and he said "Switch to Claude doc"; the V8 review doc is https://claude.ai/code/artifact/cb578bd1-8995-405f-8da4-25c7846343d0.
**How to apply:** default to Claude Docs (load the docs skill, birth the skeleton first, fill one section per call); pointy only if Kevin asks. One consolidated, readable doc (not a v2+delta pair). pointy rejects tables without `<tbody>` ("round-trip failed"). Related: [[feedback-investigation-writeups-go-to-arti]].
