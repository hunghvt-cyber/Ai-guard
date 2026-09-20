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

Network access is currently **disabled as an enforcement feature**. The CLI rejects `--network host`; the policy also requires `NETWORK=none`.

An egress-controlled mode may be added later, but it must not use host networking as a security boundary.

## Gemini integration status

The current FnNAS Gemini launcher is a Docker/Compose launcher under `/vol1/Docker/gemini`. The existing Gemini adapter intentionally does not expose `/vol1` or Docker sockets.

Therefore this repository currently provides a hardened generic sandbox, but it does **not yet enforce the existing FnNAS Gemini Docker launcher**. A future Gemini backend must place the Docker boundary behind Guard without granting the agent Docker-socket control.

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
