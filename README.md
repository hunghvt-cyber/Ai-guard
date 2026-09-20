# AI Guard

External enforcement layer for AI CLI agents on Linux.

## Design

```
Gemini / Qwen / future agent
            |
         adapter
            |
         AI Guard
            |
        Bubblewrap
            |
          Linux
```

AI Guard is agent-agnostic: adapters select the CLI, while the Guard owns the OS-level boundary.

## Security baseline

The default Guard is deny-by-default:

- only the supplied workspace is writable on the host
- the workspace cannot overlap the Guard installation or protected host roots
- `/home` and `/root` are sandbox-local
- `/etc` is sandbox-local with only minimal identity files exposed
- `/vol1` is not mounted
- Docker/containerd sockets are not mounted
- SSH credentials are not mounted
- PID, IPC and UTS namespaces are isolated
- a user namespace is explicitly created
- nested user namespaces are disabled inside the sandbox
- all Linux capabilities are dropped inside the sandbox
- a new session is created for the sandbox process
- network is isolated by default and is currently the only accepted mode
- sandbox dies with its parent
- environment is cleared except for a minimal safe runtime
- no Docker socket or host-control interface is intentionally exposed
- Guard refuses to run as UID 0

Bubblewrap provides the namespace and filesystem primitives; the Guard scripts define the actual policy.

## Workspace boundary

The writable workspace is deliberately treated as untrusted data. Before Bubblewrap starts, the Guard canonicalizes the workspace and refuses:

- the Guard installation itself or any child of it
- `/`, `/root`, `/home`, `/etc`, `/usr`, `/var`, `/vol1`
- `/proc`, `/sys`, and `/dev`

The policy file must remain inside the Guard installation because it is sourced by the host-side launcher before entering the sandbox.

## Network

Network access is **disabled by default and remains the security boundary**. The CLI rejects `--network host`; the policy requires `NETWORK=none`.

A narrow GitHub SSH capability is available without sharing the sandbox network:

- host-side relay has a fixed destination: `github.com:22`
- sandbox reaches the relay only through a private Unix socket
- GitHub SSH config and known-hosts are injected read-only
- GitHub authentication and `git ls-remote` have been validated
- arbitrary destinations such as `google.com` remain unreachable

This capability is not a general proxy and does not provide host networking.

## Hardening decision

Landlock is intentionally out of scope.

Seccomp was evaluated as defense-in-depth and intentionally deferred because the current Bubblewrap boundary already provides the required isolation without introducing a large syscall allowlist maintenance burden.

Do not add another hardening mechanism without a concrete requirement and a minimal POC proving its value.

## Gemini integration status

The Guard repository now contains the generic enforcement boundary and Gemini operating notes/rules. Full replacement of the existing FnNAS Gemini launcher is a separate integration task and must not be implied by the generic Guard tests.

The security boundary is AI Guard enforcement, not `GEMINI.md` or other Markdown instructions.

## Usage

```bash
./bin/ai-guard --workspace "$PWD" -- /bin/sh
```

Network-disabled is the only supported mode.

Run the isolation tests:

```bash
./tests/run.sh
```

This remains a security prototype. It should not be treated as production-ready until the test suite passes on the actual FnNAS host and the Gemini integration is independently validated.

## Layout

```
bin/ai-guard
sandbox/bwrap.sh
adapters/gemini
adapters/qwen
policy/default.conf
tests/run.sh
```

## AI Context

AI Guard also provides a lightweight external-memory and project-context layer for AI assistants.

```
NOTES.md
projects/
  NAS/
    NOTES.md
  GEMINI/
    NOTES.md
    runtime/       # approved runtime templates
  TAPO-NAS/
    NOTES.md
```

Principles:

- project-specific AI reminders live under the corresponding `projects/<PROJECT>/` directory
- `NOTES.md` contains stable facts and lessons
- do not duplicate the same rule in multiple project files
- project repositories remain the source of truth for code, tests, architecture, and detailed handoff documents
- project repositories may contain a short `AI-GUARD.md` pointer to their applicable AI Guard context
- enforcement code remains separate from project context
