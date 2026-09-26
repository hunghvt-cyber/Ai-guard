# Clay SSH capability

## Scope

Clay can optionally receive a dedicated SSH private key through AI Guard and use the host network namespace to SSH to FnNAS.

This capability is explicit. It is not enabled by the default policy.

## Flow

```
Clay worker
  -> AI Guard
     -> Bubblewrap
        -> /run/secrets/CLAY_SSH_KEY (read-only)
        -> host network (explicit)
  -> ssh clay@127.0.0.1
  -> sudo -n ...
  -> host
```

## Properties

- Dedicated Clay SSH identity; no Gemini key or Gemini path is involved.
- Private key is injected as a file secret, not an environment variable.
- The key is not placed in the workspace or command-line arguments.
- `--ssh-key` requires `--network host`.
- SSH capability is opt-in; default network remains `none`.
- Docker sockets and `/vol1` remain unmounted.
- The host-side `clay` account is separately managed from `admin`.
- Host privilege is determined by the `clay` account's sudo policy.

## Adapter usage

```bash
./adapters/clay \
  --provider groq \
  --network host \
  --ssh-key /path/to/clay_ssh_ed25519 \
  --worker /path/to/clay-worker \
  --workspace /path/to/workspace \
  -- \
  --cwd /workspace
```

Inside the worker sandbox, the key is available at:

```
/run/secrets/CLAY_SSH_KEY
```

The adapter also exports `CLAY_SSH_KEY_PATH` with that path for the worker.

## Security boundary

The SSH connection is a host-control path. Host network mode is therefore intentionally explicit and should not be treated as an egress-only sandbox.

The SSH account and sudo policy are outside this repository's enforcement boundary. AI Guard controls whether the worker receives the credential and host network capability.
