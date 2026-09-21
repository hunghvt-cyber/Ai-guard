# Gemini CLI — AI Notes

## Role

Gemini CLI is an execution/audit assistant, not the architect.

ChatGPT/user decides the architecture and scope. Gemini executes or audits only the requested task.

## FnNAS access

Preferred host access when available:

```bash
ssh fnnas
```

Important: `fnnas` can fail from some terminal/session environments. In that case the established fallback is:

```bash
ssh admin@100.94.158.94
```

The IP is a valid operational fallback, not a different host or a policy violation. Do not blindly insist on `fnnas` when the hostname path is actually failing.

## Default workflow

```
AUDIT -> OBSERVE -> REPORT -> STOP
```

Unless explicitly instructed otherwise:

- do not modify
- do not install
- do not restart
- do not delete
- do not repair
- do not expand scope
- do not assume missing facts
- do not continue into unrelated investigation

## Important distinction

The actual Gemini workspace instruction file remains the runtime instruction source for Gemini.

This AI Guard note is a cross-AI reminder of the established environment and role. It is not a replacement for the enforcement layer.

## GitHub authentication

- The Ai-guard repository uses the SSH remote form:
  `git@github.com:hunghvt-cyber/Ai-guard.git`
- GitHub SSH authentication from FnNAS has been verified by a successful push.
- Do not treat an HTTPS username/password prompt as evidence that GitHub credentials are missing; first check the remote.
- Do not create new GitHub credentials unless the user explicitly requests it.
- Verified: 2026-09-21.

## Gemini API Relay POC

The Gemini API Docker relay POC is complete and verified.

- Branch: `enforcement/gemini-docker-relay-poc-20260921`
- Final commit: `25f28de`
- Container network: `network_mode: none`
- Container traffic path: local TCP proxy -> Unix socket -> host relay -> `generativelanguage.googleapis.com:443`
- TLS verification result: `GEMINI_API_TLS=PASS`
- POC result: PASS
- The relay POC proves the network path can be forced through a host-controlled relay. It does not yet implement the final enforcement policy.

