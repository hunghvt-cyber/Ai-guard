# Clay-only SSH capability

This is a host-side OpenSSH forced-command gate for Clay. It is deliberately
narrow: no interactive shell, no port forwarding, no agent forwarding, no
PTY, and no arbitrary command execution.

## Allowed operations

- `uptime`
- `free`
- `df`
- `status`
- `list`
- `read /vol1/Docker/tapo-nas-lab/...`
- `stat /vol1/Docker/tapo-nas-lab/...`
- `systemctl-status UNIT`

Everything else is denied.

## Host installation

Run these commands on the real FnNAS host as an administrator. Do not put the
Clay private key into the Tapo workspace.

1. Install the gate:

```sh
install -o root -g root -m 0755 /vol1/Docker/Ai-guard/ssh/clay-ssh-gate /usr/local/libexec/clay-ssh-gate
```

2. Create a dedicated unprivileged SSH account for Clay. Do not reuse
`admin` and do not grant this account sudo or Docker group membership.

3. Create a dedicated SSH keypair for Clay. Keep the private key only in the
AI Guard secret path; never commit it and never place it in the workspace.

4. Add the public key to the dedicated account's `authorized_keys` using
OpenSSH's forced-command restrictions. The key entry should have this shape:

```text
restrict,command="/usr/local/libexec/clay-ssh-gate" ssh-ed25519 AAAA... clay-ssh
```

The `restrict` option disables PTY, agent forwarding, X11 forwarding and
TCP/stream-local forwarding for this key.

5. Verify the sshd configuration accepts the key without restarting anything
until the syntax has been checked. Prefer a configuration test with
`sshd -t` before any reload.

## Important limitation

This gate is read-only by design. It does not yet expose arbitrary host shell,
file writes/deletes, Docker control, or service restarts. Those should be added
as explicit operations only after the read-only path is proven stable.

## Network requirement

Clay must explicitly run with `--network host` to reach the NAS SSH listener.
The AI Guard default remains `NETWORK=none`; SSH is not silently enabled.

## Rollback

Remove the dedicated Clay key from `authorized_keys`, then remove the
host-side gate and dedicated account if no longer needed. Do not modify the
existing admin SSH key or account.
