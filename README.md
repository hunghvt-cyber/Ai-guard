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
- `/home`, `/root`, and `/tmp` are sandbox-local
- `/vol1` is not mounted
- Docker/containerd sockets are not mounted
- SSH credentials are not mounted
- PID, IPC and UTS namespaces are isolated
- network is isolated by default
- sandbox dies with its parent
- environment is cleared except for a minimal safe runtime
- no Docker socket or host-control interface is intentionally exposed

Bubblewrap creates a separate mount namespace and supports the namespace controls used here. citeturn0search10turn0search6

## Current Gemini limitation

The existing FnNAS Gemini launcher is a Docker/Compose launcher under `/vol1/Docker/gemini`. Safely wrapping that launcher cannot mean exposing all of `/vol1` or the Docker socket, because that would defeat the Guard boundary.

Therefore the Gemini adapter in this first version deliberately refuses to weaken the sandbox. A later Gemini backend can invoke the required container boundary from the Guard side.

## Usage

```bash
./bin/ai-guard --workspace "$PWD" -- /bin/sh
```

Network-disabled is the default. For an agent that needs outbound network:

```bash
./bin/ai-guard --network host --workspace "$PWD" -- qwen
```

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

The design was cross-checked against existing Bubblewrap agent wrappers such as `bubblewrap-ai` and `ai-bwrap`. citeturn0search0turn0search7

Qwen Code currently documents Docker/Podman sandboxing on Linux; native Bubblewrap support is being discussed upstream, so this project keeps Qwen as an adapter and owns the Linux boundary externally. citeturn0search1turn0search4

## Status

First functional prototype committed for FnNAS testing.
