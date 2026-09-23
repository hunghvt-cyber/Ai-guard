# AI Guard — Decision Ledger

This file records decisions that affect architecture or security boundaries.
It is intentionally concise and should be updated when a major decision changes.

## DEC-001 — AI Guard owns the OS boundary

CLI adapters choose the agent and credential plumbing. Bubblewrap and the
host-side Guard own the filesystem, namespace and capability boundary.

Status: active.

## DEC-002 — Do not expose /vol1 wholesale

The agent receives a controlled workspace, not unrestricted access to the NAS
data volume.

Reason: exposing /vol1 would undermine the filesystem enforcement model.

Status: active.

## DEC-003 — SSH is disabled by default

OpenCode can technically use SSH when the policy explicitly enables it, but
normal operation keeps `EXPOSE_SSH=0`.

Reason: host-admin SSH is a privileged control path. Once granted, it can
perform host-side operations outside Bubblewrap's filesystem restrictions.

Status: active.

## DEC-004 — OpenCode API key forwarding is explicit

The selected Google API key is chosen outside the sandbox and explicitly
forwarded into the sandbox environment.

Reason: avoid exposing the host environment wholesale while allowing the
agent to authenticate.

Status: active.

## DEC-005 — network=host is a capability, not a security boundary

Host networking is available for workloads that require it, but it must not be
described as egress-only or isolated networking.

Status: active.

## DEC-006 — Repo Resolver v1 is local-only

Resolver v1 accepts only canonical local workspaces under `/vol1/Docker/*`.

Reason: establish and validate the filesystem boundary before adding remote
repository resolution, credentials, or network-dependent behavior.

Status: implemented.

## DEC-007 — Canonicalize before validating

Workspace paths are resolved with `readlink -f` before boundary checks.

Reason: path traversal and symlink targets must be evaluated by their canonical
host path, not by the user-supplied spelling.

Status: implemented.

## DEC-008 — Do not rewrite published history merely for cleanliness

Experimental commits remain traceable. A stable milestone is documented by
handoff/decision files and milestone commits or tags.

Reason: rewriting already-pushed development history adds operational risk and
does not improve recoverability as much as authoritative project documentation.

Status: active.

## DEC-009 — Repository documentation is the recovery source of truth

Project state must be recoverable from repository documents without relying on
ChatGPT conversation memory.

Status: active.
