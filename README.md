# agent-memory

This is where I keep the notes Claude Code writes for itself, so they have history and every session can find them.

## Why I built it

Claude starts every session with a blank slate. It only knows what gets put in front of it at the start, which is its *context window*: the text it can see right now. Claude Code's answer is auto-memory. Claude writes short notes to `~/.claude/projects/<project>/memory/`, and an index file there, `MEMORY.md`, gets loaded at the start of each session.

That works, but I kept hitting four problems:

- **No history.** I run many sessions at once, and they all edit the same notes. A bad edit or a silent delete was gone for good.
- **A note without an index line is invisible.** Only `MEMORY.md` is loaded. Claude never goes looking for the notes themselves. When I first imported everything, 210 notes had no index line, and 27 of those were rules about how I want Claude to work.
- **Memory is tied to the folder a session starts in.** My sessions mostly start in `~/RubymineProjects`, above the repos, so they never saw the notes for treasury or nova.
- **Claude doesn't know the code's shape.** It greps around to find where something lives, every time.

## What it does

A *hook* is a script Claude Code runs on an event, like a session starting or me sending a prompt. Whatever it prints gets added to Claude's context. Most of this repo is hooks.

- **Notes live in git.** Each `~/.claude/projects/<project>/memory` is a symlink into `scopes/` here, so every change is a diff I can review or roll back.
- **The right notes load in the right session.** `hooks/memory-scope.sh` loads a repo's index when a session starts in one of its worktrees, the first time a prompt names that repo, and when a subagent starts.
- **Claude gets pointed at real code.** A map of each repo's classes and modules, and how they connect, lives in a SQLite file. `hooks/memory-retrieve.sh` matches what I'm talking about, or what a tool just read, to that map and adds the related `file:line` locations.
- **My decisions travel with the code.** Files under `concepts/<repo>/` describe one area of a repo. Anything under `## Judgment` in one is a decision I made, and it gets shown alongside that code.

## Install

You need `jq`, `sqlite3`, Ruby 3.4 (it ships the Prism parser) for Ruby repos, and `bun` for TypeScript repos. It's macOS-first: the scheduled job uses launchd.

```sh
git clone git@github.com:kwliang1/agent-memory.git ~/agent-memory
~/agent-memory/bin/install.sh --dry-run   # shows what it would do
~/agent-memory/bin/install.sh
```

It's safe to run twice. In order, it:

1. Turns on the pre-commit guard that blocks SSN- and account-shaped numbers. Git doesn't carry this setting across a clone, so a fresh clone has it off until you run this.
2. Symlinks each scope whose project folder exists on your machine, and reports the ones it skips.
3. Links `config/CLAUDE.md` to `~/.claude/CLAUDE.md`, unless you already have a real file there.
4. Adds the hooks to `~/.claude/settings.json`, saving the old file as `settings.json.bak` first.
5. Schedules `bin/reindex.sh` every 15 minutes to rebuild the code map when a repo's `main` moves.

The code map only covers repos you've indexed once by hand: `bin/index.sh ~/path/to/repo`.

## Day to day

- **Every note needs a line in its `MEMORY.md`.** Writing the file is half the job. Without the line, nothing ever loads it.
- **Changes land as PRs**, so I can review them like any other diff.

## Be careful

`~/agent-memory` is live. Every session on the machine reads from it right now.

- **Never run `git clean`, `git checkout -- .`, or `git reset --hard` here.** A note is untracked until someone commits it, and those commands delete it with no way back.
- **Never switch the main checkout to another branch.** `config/` holds the live `CLAUDE.md`, so a branch without it silently drops my rules from every new session. Use a worktree for branch work.
- **Don't leave anything staged.** Many sessions share this checkout, and the next commit from any of them picks it up.

To restore a scope from an earlier commit, copy it in from a temporary worktree so the live folder is never missing:

```sh
cd ~/agent-memory
git worktree add -q /tmp/cm-restore <ref>
rm -rf scopes/<slug> && cp -a /tmp/cm-restore/scopes/<slug> scopes/<slug>
git worktree remove /tmp/cm-restore
git reset -q scopes/<slug>
```

## Further reading

- [INTERNALS.md](INTERNALS.md): how the indexer, ranker and hooks work, the hazards in full, and how to test retrieval.
- [SPEC.md](SPEC.md): the implementation spec.
- [DESIGN.md](DESIGN.md): why it's built this way, and what I rejected.
- [HISTORY.md](HISTORY.md): how it got here.
