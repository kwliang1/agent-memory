---
name: hydra-reboot-recovery-facts
description: Verified current-code facts for hydra post-reboot recovery (slack-byte restart + worker cold-recovery + lossless links) — corrects older resurrection notes
metadata: 
  node_type: memory
  type: project
  originSessionId: 8a8e954f-a60f-4b2e-950f-8302f1638176
  modified: 2026-08-19T17:46:08.287Z
---

Verified 2026-08-19 against current main (worktree hydra-qubit) for the post-reboot-recovery build (branch kevinliang/hydra-post-reboot-recovery).

**loadPersisted no longer prunes dead workers** (`daemon/sessions.ts:314-355`). On boot it checks `tmux has-session`; alive → clears `deadAt`, dead → stamps `info.deadAt = deadAt ?? now` and KEEPS the record (only `isJoinMember` records are killed+dropped). So after a clean reboot the dead worker records survive in sessions.json WITH `artifacts[]`, `description`, `threadUrl`, `anchorMessageId`, `capabilities`, `worktreeRepo/Path` intact. This CORRECTS [[hydra-session-resurrection]] (which said kill-server pruned to []). The dashboard only renders sessions whose tmux is alive (`daemon/dashboard.ts:42`), so dead records are invisible until recovered.

**Link-loss root cause** (peer kevin-ed confirmed, I verified): per-session deliverable links live in `session.artifacts[]`, captured from the session's own outbound replies at `daemon/bridge-dispatch.ts:109-141` (guard `chat_id === info.threadId`; extractArtifactLinks→mergeArtifacts). On respawn onto an existing thread, `doSpawnSession` (`session-lifecycle.ts:536-551`) finds the dead record, carries over ONLY anchorMessageId/anchorChannelId, then `killSession(existing,'replaced by new spawn')` which `registry.delete`s it (`:291`) → new record starts with `artifacts=[]`. That kill ALSO runs `destroyWorktree` (`:270-284`, deletes branch `wt/<name>`) and `unwatchBySession` (`:294`). Boot-time `backfillArtifacts()` (`daemon.ts:348-380`, gated by `s.artifactsBackfilled`) re-derives links from thread history but only for tmux-alive sessions and only at daemon startup.

**slack-byte-didn't-restart root cause:** live loaded launchd job `com.hydra.watchdog` runs the DEPRECATED `watchdog.sh` with `CLAUDE_CONFIG_DIR=/Users/kevin/.claude-byte` (from `~/.claude/channels/slack/.env`). But Kevin runs the daemon MANUALLY with `CLAUDE_CONFIG_DIR=/Users/kevin/.claude` (verified in `ps`: cwd RubymineProjects/hydra, logs to hydra-slack-daemon.log). The `.claude-byte` byte crash-loops — `~/hydra-watchdog.log` shows "Bot session 'slack-byte' missing (daemon alive), reviving" every 120s for WEEKS. Deprecated `start-byte.sh:84` also hardcodes `--model claude-opus-4-6[1m]` (2 behind current opus-4-8; .env sets HYDRA_MODEL=opus-4-8) and ignores HYDRA_CLAUDE_TOKEN_FILE (only reads CLAUDE_CODE_OAUTH_TOKEN / ~/.angellist-claude-token). The maintained path is the CLI: `cli/lifecycle.ts` (`hydra up/watchdog/install/restart`) — `startByte` uses spawnModel() + HYDRA_AUTH=keychain option; `lifecycleInstall` writes a NEW plist labeled `com.hydra.watchdog.<platform>` (so it would COEXIST with the legacy unlabeled one → double-watchdog). CLI watchdog is NOT installed (launchctl shows only legacy `com.hydra.watchdog`).

**Existing recovery primitives to reuse:** manual chat command `recover [name]` = `handleRecoverIntercept`/`recoverOne`/`findDeadSessions` (`daemon/commands/global.ts:277-414`) does resume→fork→resurrect cascade in waves of 2 (STAGGER 5s). `tryResume`/`tryRespawn` (`session-lifecycle.ts:926-1016`) are the building blocks; `tryResume` uses `--resume claudeSessionId` for full context + orphan handling. There is NO automatic boot-time invocation and NO dedup-by-PR.

**⚠ do not restart the live slack daemon** (pid 5814/5912) — this session + all recovered workers route through it.
