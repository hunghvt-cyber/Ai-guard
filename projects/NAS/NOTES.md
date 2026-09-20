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
