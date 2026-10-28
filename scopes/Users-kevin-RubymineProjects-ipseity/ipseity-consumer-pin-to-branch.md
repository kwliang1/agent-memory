---
name: ipseity-consumer-pin-to-branch
description: Never merge a consumer repo while its Gemfile pins entity_api to an ipseity branch; squash-merge deletes the branch
metadata:
  type: feedback
---

A consumer (noto, venture, treasury) testing an unreleased `entity_api` change often pins `branch: 'kevinliang/…'`. ipseity squash-merges and deletes the branch, so a consumer merged with that pin can no longer `bundle install`. It happened once with noto.

**How to apply:** before a consumer PR merges, re-pin it to the released gem version, and check its Gemfile for `branch:` on any ipseity gem. Related: [[ipseity-entity-api-commit-compiled]].
