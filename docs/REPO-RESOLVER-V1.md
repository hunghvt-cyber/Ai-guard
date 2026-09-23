# Repo Resolver v1

Status: IMPLEMENTED AND LOCALLY VALIDATED

## Purpose

Repo Resolver v1 defines the local workspace boundary accepted by AI Guard.

The resolver is intentionally limited to local filesystem resolution. It does not
clone repositories, access GitHub authentication, or resolve remote repositories.

## Controlled workspace root

Allowed repository workspaces must resolve under:

    /vol1/Docker/*

The exact path:

    /vol1/Docker

is denied.

The AI Guard installation itself is also denied as a workspace.

## Canonicalization

The requested workspace is canonicalized with:

    readlink -f

before boundary validation.

This prevents path traversal and symlink escapes from bypassing the controlled
workspace boundary.

Examples denied by canonicalization include:

- /vol1/Docker/<repo>/../../../../home/admin
- symlink resolving to /home/admin
- symlink resolving to /vol1/Docker/Ai-guard

A symlink resolving to another location under /vol1/Docker remains within the
v1 controlled root.

## Protected paths

The resolver denies protected host locations including:

- /root
- /home
- /etc
- /usr
- /var
- /proc
- /sys
- /dev

It also denies:

- /vol1
- /vol1/Backups
- /vol1/docker
- /vol1/Docker
- /vol1/Docker/Ai-guard

## Workspace semantics

A valid repository under /vol1/Docker is exposed to the sandbox as:

    /workspace

The workspace is the writable working area.

The Guard installation and other host filesystem locations remain outside the
workspace write boundary.

## Security boundary

Repo Resolver v1 is only the workspace-selection and local-boundary layer.

It does not provide:

- GitHub repository cloning
- GitHub authentication
- remote repository lookup
- network-based repository resolution
- SSH access

SSH remains disabled by default:

    EXPOSE_SSH=0

SSH is a separate privileged channel and is not part of Repo Resolver v1.

## Validation

Local validation performed on 2026-09-23:

- valid repository: PASS
- exact /vol1/Docker: DENY
- AI Guard installation: DENY
- /vol1: DENY
- /vol1/Backups: DENY
- /vol1/docker: DENY
- /home/admin: DENY
- canonical path traversal: DENY
- symlink to /home/admin: DENY
- symlink to AI Guard installation: DENY

Shell syntax validation:

    sh -n bin/ai-guard

passed.

Git whitespace validation:

    git diff --check

passed.

## Future work

Repo Resolver v2 may add controlled remote GitHub repository resolution.

That must be designed as a separate capability and must not weaken the local
filesystem boundary established by v1.
