---
name: treasury-console-pod-stdin-eof-workaround
description: "treasury prod write console self-terminates ~18s after create (rails console gets stdin EOF); SIGSTOP the main process to hold the pod open"
metadata:
  node_type: memory
  type: reference
---

**2026-09-18:** the treasury prod **write** console is unusable as shipped. `bundle exec rails console`
(the pod's `args`) receives stdin EOF ~8s after boot, prints its prompt, exits 0, the pod goes
`Completed` at ~18s, and konsoled deletes the Konsole — which also deletes the k8s Role named
`console`, so every later call fails with `RBAC: role.rbac.authorization.k8s.io "console" not found`.
Any `al console exec` still running dies with **exit 137**. Read console is separately Forbidden
(`treasury-ro`) because GlobalConsoleWriters revokes it — see [[al-console-treasury-rbac]].

Reproduced three ways, so it is not a pty artifact: `al console create` (attach), a direct
`kubectl attach -i -t` racing the container start, and a real terminal via `tmux new-session`.
Pod spec is `stdin=true stdinOnce=<unset> tty=true`; 8 GiB limit, `memory.events oom_kill 0` — not OOM.

**Workaround — SIGSTOP the main process so it never reaches its stdin read:**
```sh
al console delete -a treasury -p -w                      # clear the stale CR
al console create --no-attach -a treasury -p -w &        # then poll for Running
kubectl get pod -n treasury console-write-kevin.liang-0 -o jsonpath='{.status.phase}'
kubectl exec -n treasury console-write-kevin.liang-0 -c main -- \
  sh -c "pkill -STOP -f 'rails cons''ole'; kill -STOP 1"
```
Stop **both** PID 1 (`docker-entrypoint.sh`) and the `ruby bin/rails console` child — stopping PID 1
alone lets the child exit and the pod still completes. Split the `pkill` pattern (as above) or the
`sh -c` stops itself, since its own argv matches. Exec must fire within ~10s of Running.

A SIGSTOPped pod cannot reap SIGTERM, so `al console delete` sits in `Terminating` for the full
grace period and a fresh `create` fails until it clears — wait it out rather than retrying.

Pod then stays Running indefinitely and normal work resumes:
`al console push -a treasury -p -w <local> /tmp/x.rb` then
`kubectl exec -n treasury console-write-kevin.liang-0 -c main -- bundle exec rails runner /tmp/x.rb`
(plain `al console exec` works too). Frec + all prod reads worked from this pod. `kubectl` is on PATH,
context `zeus`. Delete the console when done.

Still broken on retest 2026-09-19 00:20 UTC, attached path included — Kevin expected it to have
self-recovered and it had not.

**Why:** without this every prod query in the session fails with 137 or a Forbidden that reads like a
permissions problem. Used to diagnose [[mmf-frec-uninvested-cash-drift]].
