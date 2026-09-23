# AI Guard + OpenCode v1 Plan

## Status

As of 2026-09-23, the OpenCode integration has passed the core sandbox E2E baseline.

### Proven

- OpenCode 1.18.32 runs inside AI Guard/bubblewrap.
- Selected workspace is read/write.
- /vol1 is mounted read-only.
- /vol1/Docker/Ai-guard is read-only from inside the sandbox.
- /var/run/docker.sock is absent.
- User/PID/IPC/UTS/mount isolation is active.
- OpenCode can reach Gemini API when explicitly run with network=host.
- network=none correctly blocks the Gemini API.
- OpenCode permission `external_directory` is an application-level permission layer, not the security boundary.
- The OpenCode compaction `experimental.compaction.autocontinue` mechanism exists in 1.18.32 and the global plugin loader has been verified. Do not spend further effort on synthetic huge-command-line compaction tests.

## Security model

OpenCode permissions are UX/approval controls.

AI Guard is the security boundary.

bubblewrap/Linux namespaces provide the enforcement layer.

Target model:

```
OpenCode
  |
  v
AI Guard policy
  |
  v
bubblewrap
  +-- selected workspace: RW
  +-- /vol1: RO
  +-- Ai-guard: RO
  +-- sensitive host paths: protected/hidden
  +-- docker.sock: absent
  +-- network: explicit policy
```

## Current policy

- Default network: `none`.
- `host` network is an explicit mode for API access and must not silently become the default.
- Workspace paths must be canonicalized with `readlink -f`.
- Workspace must remain under the controlled repository root.
- Ai-guard installation must never be a writable workspace.
- Protected host paths remain rejected.
- No Docker socket exposure.
- No GitHub push authority is delegated to OpenCode by default.

## OpenCode permission handling

Do not attempt to replace OS-level enforcement with OpenCode permissions.

The `external_directory` permission may be configured to reduce unnecessary approval prompts for the selected workspace, but it is not trusted for filesystem security.

The observed OpenCode behavior:

```
permission requested: external_directory (/vol1/*, /vol1/Docker/Ai-guard/*)
auto-rejecting
```

is an OpenCode application-level behavior. It does not indicate that bubblewrap isolation failed.

## Remaining v1 work

1. Make OpenCode permission configuration compatible with the selected workspace without weakening AI Guard enforcement.
2. Implement/verify generic repository/workspace resolution:
   - use an existing repository when present;
   - clone a requested repository when missing and credentials permit;
   - stop rather than broaden permissions when access is unavailable.
3. Fix multi-key API selector propagation through the sandbox. Current `--clearenv` removes `GOOGLE_GENERATIVE_AI_API_KEY`; auth.json currently allows tests to work but does not prove selector propagation.
4. Verify controlled SSH behavior.
5. Define the explicit network policy for normal OpenCode operation.
6. Run adversarial filesystem tests against the real OpenCode workflow.

## Hardening backlog (after v1)

- Test whether OpenCode/Node/Bun requires nested user namespaces; consider bubblewrap `--disable-userns` only after compatibility testing.
- Evaluate seccomp BPF as an additional hardening layer. Do not copy an x86_64 filter onto the aarch64 NAS without architecture-specific testing.
- Consider restricted network proxy/domain allowlisting after the basic workflow is stable.

## Validation requirements before v1 release

The following must all pass:

- workspace RW;
- other /vol1 content RO;
- Ai-guard RO;
- protected host paths inaccessible;
- docker.sock absent;
- OpenCode runs inside Guard;
- selected model/API works under the chosen network policy;
- SSH works only when explicitly enabled;
- multi-key selection reaches the intended OpenCode process;
- repository selection cannot escape the controlled root;
- no unintended host writes from agent tools.

## Working rule

Do not broaden scope while these validation items are open.

Use the repository as the source of truth for the implementation plan and update this document when a validation item is completed or its design changes.
