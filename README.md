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

## Security defaults

- only the supplied workspace is writable on the host
- the workspace cannot overlap the Guard installation or protected host roots
- `/home`, `/root`, and `/tmp` are sandbox-local
- `/vol1` is not mounted
- Docker/containerd sockets are not mounted
- SSH credentials are not mounted
- PID, IPC and UTS namespaces are isolated
- all Linux capabilities are dropped inside the sandbox
- a new session is created for the sandbox process
- network is isolated by default
- sandbox dies with its parent
- environment is cleared except for a minimal safe runtime
- no Docker socket or host-control interface is intentionally exposed
- Guard refuses to run as UID 0

Bubblewrap creates a separate mount namespace and provides the namespace controls used here.

## Workspace boundary

The writable workspace is deliberately treated as untrusted data. Before Bubblewrap starts, the Guard canonicalizes the workspace and refuses:

- the Guard installation itself or any child of it
- `/`, `/root`, `/home`, `/etc`, `/usr`, `/var`, `/vol1`
- `/proc`, `/sys`, and `/dev`

The default policy file must remain inside the Guard installation because it is sourced by the host-side launcher before entering the sandbox.

## Network modes

`--network none` is the default and uses a separate network namespace.

`--network host` intentionally disables network namespace isolation. It gives the sandbox access to the host network namespace, including interfaces and services reachable through that namespace. It is **not** an outbound-only mode and should not be treated as a security boundary.

An egress-only mode using slirp4netns/pasta or an allowlisted proxy is a later hardening task.

## Current Gemini limitation

The existing FnNAS Gemini launcher is a Docker/Compose launcher under `/vol1/Docker/gemini`. Safely wrapping that launcher cannot mean exposing all of `/vol1` or the Docker socket, because that would defeat the Guard boundary.

Therefore the Gemini adapter in this first version deliberately refuses to weaken the sandbox. A later Gemini backend can invoke the required container boundary from the Guard side.

## Usage

```bash
./bin/ai-guard --workspace "$PWD" -- /bin/sh
```

Network-disabled is the default.

For diagnostics only, an agent may be run with the host network namespace:

```bash
./bin/ai-guard --network host --workspace "$PWD" -- qwen
```

This mode is intentionally not network-isolated.

Run the isolation tests:

```bash
./tests/run.sh
```

This is an early security prototype. It is not considered production-ready until the test suite and independent security review pass.

## Layout

```
bin/ai-guard
sandbox/bwrap.sh
adapters/gemini
adapters/qwen
policy/default.conf
tests/run.sh
```

## Existing work

The design was cross-checked against existing Bubblewrap agent wrappers such as `bubblewrap-ai` and `ai-bwrap`.

Qwen Code currently documents Docker/Podman sandboxing on Linux; native Bubblewrap support is being discussed upstream, so this project keeps Qwen as an adapter and owns the Linux boundary externally.

## Status

Security-hardening prototype committed for FnNAS testing. The real FnNAS test remains pending; no kernel changes are required by this repository.
