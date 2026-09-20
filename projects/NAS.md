# FnNAS — AI Notes

## Host identity

- Canonical hostname: `fnnas`
- Preferred SSH access: `ssh fnnas`
- Tailscale fallback when hostname resolution fails: `ssh admin@100.94.158.94`
- Do not replace the canonical hostname with an IP just because the IP is available.
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
