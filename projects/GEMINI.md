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

GEMINI.md is an instruction file for Gemini.

This AI Guard note is a cross-AI reminder of the established environment and role. It is not a replacement for the enforcement layer.
