---
name: rubymine-pins-old-ruby
description: Why ASDF_RUBY_VERSION=3.4.5 keeps overriding .tool-versions (3.4.8) — RubyMine project SDK
metadata: 
  node_type: memory
  type: reference
  originSessionId: 688baa71-c765-435d-aa0e-d7fd30501c03
---

Root cause of the recurring `Bundler::RubyVersionMismatch` (session Ruby 3.4.5 vs Gemfile/.tool-versions 3.4.8): the Claude session is launched from **RubyMine's embedded terminal**, whose `asdf_starter.sh` runs `export ASDF_RUBY_VERSION=$RUBY_VERSION_MANAGER_DISTRIBUTION_ID`. `RUBY_VERSION_MANAGER_DISTRIBUTION_ID` is set by RubyMine from the **project's configured Ruby SDK** (asdf 3.4.5). `ASDF_RUBY_VERSION` takes precedence over `.tool-versions`, so 3.4.5 wins even though repo + `~/.tool-versions` say 3.4.8.

Tells: env has `__CFBundleIdentifier=com.jetbrains.rubymine`, `JEDITERM_SOURCE=.../RubyMine.app/.../terminal/asdf_starter.sh`, `RUBY_VERSION_MANAGER_DISTRIBUTION_ID=3.4.5`. Shell rc files are clean — it is NOT `.zshrc`/`.zprofile`.

Permanent fix: RubyMine → Settings → Languages & Frameworks → Ruby SDK and Gems → set project interpreter to Ruby 3.4.8 (asdf, already installed). Then embedded terminals export 3.4.8 and pre-commit hook / bundle / rubocop / srb work with no per-command `unset`.

Workarounds for a running session (env cached at launch, can't be fixed mid-session): launch Claude from a standalone iTerm/Terminal.app instead, or `unset ASDF_RUBY_VERSION` inside each Bash command (does NOT reach PreToolUse hooks — they inherit the stale session env). See [[treasury-worktree-spec-run]].
