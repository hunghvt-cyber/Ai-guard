# AI Guard

External enforcement layer for AI CLI agents on Linux.

## Current status

**Current milestone: OpenCode Guard + Repo Resolver v1**

The current development baseline is the `work/opencode-sandbox-20260923`
branch. The latest milestone commit is:

```
ff92449 feat(resolver): enforce controlled repository workspace
```

For project recovery and the current state, read
`docs/PROJECT-HANDOFF.md` first.

## Design

```
AI CLI
  |
adapter / selector
  |
AI Guard
  |
Bubblewrap
  |
Linux
```

AI Guard is agent-agnostic: adapters select the CLI and credential plumbing,
while the Guard owns the OS-level enforcement boundary.

## Security defaults

- only the supplied workspace is writable
- the workspace cannot overlap the Guard installation
- protected host roots are rejected
- `/vol1` is not exposed wholesale
- Docker/containerd sockets are not exposed
- SSH is disabled by default
- Linux capabilities are dropped
- selected PID/IPC/UTS namespaces are isolated
- environment is explicitly rebuilt
- network is isolated by default
- the sandbox dies with its parent
- Guard refuses to run as UID 0

See `docs/ARCHITECTURE.md` and `docs/DECISIONS.md` for the security model.

## OpenCode

OpenCode is currently the primary tested AI CLI integration.

The adapter/selector lives under:

```
adapters/opencode/
```

Google API key selection happens outside the sandbox and the selected key is
explicitly forwarded into the sandbox.

## Repo Resolver v1

Resolver v1 accepts canonical local workspaces under:

```
/vol1/Docker/*
```

It rejects the exact `/vol1/Docker` root, the Guard installation, protected
host paths, and canonical traversal/symlink escapes.

It does **not** clone or resolve remote GitHub repositories.

See `docs/REPO-RESOLVER-V1.md`.

## Network

`--network none` is the default.

`--network host` intentionally shares the host network namespace and must not
be treated as a security boundary.

## Usage

```bash
./bin/ai-guard --workspace "$PWD" -- /bin/sh
```

Run the existing isolation tests:

```bash
./tests/run.sh
```

## Documentation

Start here:

1. `docs/PROJECT-HANDOFF.md`
2. `docs/DECISIONS.md`
3. `docs/ARCHITECTURE.md`
4. `docs/REPO-RESOLVER-V1.md`

These documents are the project recovery source of truth; do not rely on
conversation history to reconstruct the current state.
