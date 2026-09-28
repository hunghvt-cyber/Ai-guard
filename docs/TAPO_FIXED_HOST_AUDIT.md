# Fixed Tapo host audit

This branch adds a fixed, read-only host-audit capability.

## Files

- `adapters/tapo-host-audit`: SSH launcher. It accepts only the SSH key and target; it does not accept a remote command.
- `tools/tapo-host-audit`: the fixed remote audit command set.

## Installation on FnNAS

After pulling the branch:

```sh
cd /vol1/Docker/Ai-guard
chmod 0555 tools/tapo-host-audit adapters/tapo-host-audit
sudo install -o root -g root -m 0555 tools/tapo-host-audit /usr/local/libexec/tapo-host-audit
```

The installed host script is the command that the adapter invokes. It contains only read-only inspection commands.

## Important boundary

This prototype is deliberately separate from the normal Clay worker. Gemini/Clay does not receive the SSH private key and does not supply the remote command.

The intended next integration is:

```
Gemini/Clay
    -> fixed capability
    -> adapters/tapo-host-audit
    -> /usr/local/libexec/tapo-host-audit
    -> stdout
```

No GitHub write/publish operation is part of this capability.
