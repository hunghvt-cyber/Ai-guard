# AI Guard — Project Handoff

## Current baseline

- Repository: `hunghvt-cyber/Ai-guard`
- Current development branch: `work/opencode-sandbox-20260923`
- Last implementation commit: `ff92449` — `feat(resolver): enforce controlled repository workspace`
- Current milestone: OpenCode Guard + Repo Resolver v1
- Resolver v1: implemented, locally validated, committed and pushed
- SSH: disabled by default (`EXPOSE_SSH=0`)
- Docker socket: not exposed
- Host `/vol1`: not exposed wholesale

## Current architecture

```
OpenCode
   |
adapter / selector
   |
AI Guard
   |
Bubblewrap
   |
Linux
```

AI Guard is the enforcement layer. CLI-specific adapters select the agent and
credentials; the OS boundary remains owned by AI Guard.

## Implemented capabilities

### Sandbox

- Bubblewrap mount namespace
- writable workspace mapped as `/workspace`
- Guard installation excluded from workspace
- protected host roots rejected
- Linux capabilities dropped
- PID/IPC/UTS isolation according to policy
- environment cleared and rebuilt with a minimal runtime
- Docker/containerd sockets absent
- sandbox lifetime tied to parent
- `network=none` default
- `network=host` available as an explicitly weaker capability

### OpenCode

- OpenCode adapter/selector exists under `adapters/opencode/`
- Google API key selection is handled outside the sandbox
- selected `GOOGLE_GENERATIVE_AI_API_KEY` is explicitly forwarded into the sandbox
- real OpenCode E2E execution through AI Guard was validated
- normal SSH capability is disabled

### Repo Resolver v1

Implemented in `bin/ai-guard` and documented in `docs/REPO-RESOLVER-V1.md`.

Rules:

- workspace must canonicalize under `/vol1/Docker/*`
- exact `/vol1/Docker` is denied
- AI Guard installation is denied
- protected roots and unrelated `/vol1` paths are denied
- `readlink -f` is applied before boundary checks
- traversal and symlink escapes are therefore checked after canonicalization
- v1 is local-only; it does not clone or resolve GitHub repositories

Validated on 2026-09-23:

- valid repository: PASS
- `/vol1/Docker`: DENY
- AI Guard installation: DENY
- `/vol1`: DENY
- `/vol1/Backups`: DENY
- `/vol1/docker`: DENY
- `/home/admin`: DENY
- canonical traversal to `/home/admin`: DENY
- symlink to `/home/admin`: DENY
- symlink to AI Guard: DENY
- `sh -n bin/ai-guard`: PASS
- `git diff --check`: PASS

## Important security decisions

1. SSH is not enabled for normal OpenCode operation. Unrestricted SSH using the
   host admin account is a privileged host-control channel and can bypass the
   filesystem sandbox.
2. `network=host` is not treated as a security boundary.
3. The agent must not receive unrestricted `/vol1` access.
4. Repo Resolver v1 deliberately avoids GitHub clone/auth/network resolution.
5. Chat history is not the source of truth. Repository documentation is.

## Known limitations

- Repo Resolver v2 (remote GitHub resolution) is not implemented.
- No egress-only network mode is implemented.
- Independent adversarial security review is still pending.
- Working-tree backup/state artifacts may exist locally on FnNAS and are not
  part of the committed project baseline.

## Next work

Do not expand scope automatically. Continue from this handoff.

Potential future work, only when explicitly selected:

1. adversarial E2E audit
2. controlled Repo Resolver v2
3. stronger network egress control
4. cleanup of local backup/state artifacts

## Recovery rule

When starting a new conversation or returning after a long gap:

1. read this file;
2. read the component-specific document relevant to the task;
3. inspect the current branch and HEAD;
4. only then inspect implementation details.

Do not reconstruct project state from memory alone.
