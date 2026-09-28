# Tapo SSH policy V1

This policy is a host-side SSH forced-command gateway for the dedicated `clay` key.

It is intentionally small. It does not replace AI Guard/Bubblewrap.

## Install

```sh
cd /vol1/Docker/Ai-guard
chmod 0555 tools/tapo-ssh-policy
sudo install -o root -g root -m 0555 tools/tapo-ssh-policy /usr/local/libexec/tapo-ssh-policy
```

Add the dedicated Clay public key to the `clay` account's `authorized_keys` with a forced command:

```text
command="/usr/local/libexec/tapo-ssh-policy",restrict ssh-ed25519 <CLAY_PUBLIC_KEY>
```

Do not put the key in the `admin` account.

## V1 policy

Allowed read/inspection families:

- `hostname`, `id`, `uname`
- `find`, `ls`, `wc`, `stat`, `du` under `/recordings`
- `tail`, `wc`, `grep` for Tapo event files
- `git -C /vol1/Docker/tapo-nas-lab ...`
- `systemctl is-active/status ...`
- `docker ps`
- `rclone listremotes`, `rclone lsf ...`

Denied:

- shell composition: pipe, ampersand, semicolon, redirection
- sudo/su/doas
- rm/mv/cp/chmod/chown/kill
- reboot/shutdown/poweroff
- systemctl restart/stop/disable/mask
- docker rm/stop/kill/exec/compose
- rclone copy/move/delete/purge

The policy fails closed.

## Important

V1 is intentionally read-only. It is a first boundary test, not a general shell parser.

The Clay account must not have unrestricted sudo. Verify and remove any broad sudo rule before treating this as the production boundary.
