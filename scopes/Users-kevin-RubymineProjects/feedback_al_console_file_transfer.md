---
name: Use al console push/pull for file transfer to/from prod consoles
description: When the user has an `al console` session open and needs to run a local script in it (or retrieve a file from it), use `al console push`/`al console pull` — never suggest `pbcopy` or paste-into-terminal
type: feedback
originSessionId: 744c4a3c-0259-4f65-8971-6a2a659252f9
---
When the user has a remote `al console` session open (created via `al console create -a <app> -e prod` or `al console c -a <app> -p`) and needs to run a local script there or retrieve a file from it, use the AngelList CLI's file-transfer subcommands:

- **Local → pod:** `al console push <local-path> <pod-path> -a <app> -p [-n <num>] [-l]`
- **Pod → local:** `al console pull <pod-path> <local-path> -a <app> -p [-n <num>] [-l]`

Then in the Rails console: `load '<pod-path>'`.

**Why:** `pbcopy` + paste is the wrong workflow — it's slow for large files, terminals choke on multi-hundred-line pastes, and the user has a proper transfer command available. The `al` CLI (`/Users/kevin/bin/al`) has dedicated `push`/`pull` subcommands that copy files between the local FS and the remote console pod.

**How to apply:**
- Match the flags to the session the user already has open: same `-a` (app), same `-p` / `-e` (env), same `-n` (console number — defaults to `0`), and same `-l` (legacy) if applicable.
- **NEVER print a bare `al console push <src> <dst>` or `al console pull <src> <dst>` without the `-a <app>` flag at minimum** — including in script `puts` lines that hint at next steps, prompts handed to other Claude sessions, or chat suggestions. The bare form looks complete but silently targets the wrong (or no) session. If the user hasn't told you the app, leave a `<APP>` placeholder rather than emitting a flagless command.
- The default read-only console is fine for read-only scripts; only suggest `-w` (write) if the script actually mutates state.
- After a script writes output to `/tmp` inside the pod, follow up by suggesting `al console pull` to retrieve it (pod `/tmp` is ephemeral).
- If unsure of a flag, run `al console push --help` / `al console pull --help` rather than guessing.
