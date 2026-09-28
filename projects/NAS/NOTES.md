# FnNAS — AI Notes

## Host identity

- Canonical hostname: `fnnas`
- Preferred SSH access when the hostname path works: `ssh fnnas`
- The `fnnas` hostname is not always reliable from every terminal/session; it may fail to resolve or connect correctly.
- When `ssh fnnas` fails, use the known Tailscale fallback: `ssh admin@100.94.158.94`.
- The IP is a legitimate fallback, not an error or an alternative topology.
- Do not keep retrying `fnnas` indefinitely when the known IP fallback is required.
- Do not invent or infer a different SSH topology.
- When a task requires host operations, work on the FnNAS host through the established SSH path.

## Host facts

- Debian 12 bookworm
- aarch64
- Kernel currently tracked in project context: 6.18.18.c944-trim
- LAN address: 192.168.1.12
- Tailscale address: 100.94.158.94
- Docker root: /vol1/docker
- Main data volume: /vol1

## AI access principle

The fact that an AI can reach the host does not mean it may modify it. Access path and authorization scope are separate concerns.


## Clay task retrieval from GitHub

The Clay/Tapo operational workflow uses the FnNAS host's existing authenticated Git SSH access instead of giving Clay GitHub credentials.

Flow:

```
GitHub main / tasks/current.md
  ↓
FnNAS: git fetch origin main
  ↓
git show origin/main:tasks/current.md
  ↓
Clay reads the task through its established host SSH path
  ↓
Clay executes only the explicitly listed commands
```

Rules:

- Do not add `gh`, GitHub API credentials, or GitHub write capability to Clay for this workflow.
- Do not fetch a private repository's `raw.githubusercontent.com` URL directly from Clay; unauthenticated access returns 404.
- Do not use `git pull` on the Tapo working tree just to retrieve a task, because the checkout may be on a non-main branch and must not be disturbed.
- Prefer `git fetch origin main` + `git show origin/main:tasks/current.md`.
- GitHub remains the durable source of truth; Clay is an execution consumer.
- The host's GitHub SSH authentication is outside the Clay sandbox and is not exposed to Clay as a credential.
- Verified on 2026-09-28: FnNAS can successfully fetch `origin/main` from `github.com` for `hunghvt-cyber/tapo-nas-lab`.


## Clay SSH to FnNAS — verified

**Verified: 2026-09-28**

The dedicated Clay SSH identity is proven against the real FnNAS host:

- SSH user: `clay`
- Host: `100.94.158.94`
- Private key source: `/home/clay/.ssh/id_ed25519` on the invoking admin environment
- Injection: AI Guard `--secret-file CLAY_SSH_KEY`
- Runtime path: `/run/secrets/CLAY_SSH_KEY`
- Environment path: `CLAY_SSH_KEY_PATH=/run/secrets/CLAY_SSH_KEY`
- Network: explicit `--network host`
- Clay mode used for proof: `unleashed-auto`
- Result: `CLAY_ADMIN_HOST_OK`

The same dedicated key was tested against `admin@100.94.158.94` and was rejected with `Permission denied (publickey,password)`. This confirms the intended authorization is the dedicated `clay` account, not `admin`.

Do not weaken this model by installing the Clay public key into the admin account. Host operations requiring elevated privileges should use the existing `clay` account sudo policy and remain constrained by the explicit task and AI Guard boundary.

For the Tapo workflow, the target is now:

```
clay@100.94.158.94
```

The Tapo task file on GitHub main has been aligned with this target. Clay remains a read/execute consumer and must not gain GitHub write capability.
