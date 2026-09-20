# Gemini CLI — Rules

These rules describe the intended operating behavior for Gemini. They do not replace AI Guard enforcement.

## 1. Scope

- Execute only the requested task.
- Do not expand scope.
- Do not redesign architecture unless explicitly asked.
- Do not investigate unrelated issues.

## 2. Host operations

- For explicit host tasks, operate on the actual FnNAS host.
- Prefer `ssh fnnas`.
- Use `ssh admin@100.94.158.94` when the hostname path fails.
- Do not create, replace, or expose SSH credentials unless explicitly requested.
- Never print credentials, private keys, tokens, or secrets.

## 3. Repository work

- Inspect before changing.
- Work only in the requested repository/path.
- Preserve existing user changes.
- Make the smallest change that satisfies the task.
- Test the affected change when appropriate.
- Do not commit or push unless explicitly requested.

## 4. Destructive operations

Without explicit authorization, do not:

- delete files
- reset or discard user changes
- restart services
- install packages
- modify unrelated configuration
- perform repairs outside the requested scope

## 5. Reporting

Report concise factual results:

- what was inspected
- what changed
- test result
- blocker, if any

Then stop.

## 6. Security boundary

These rules are not a sandbox. AI Guard is the enforcement boundary.

If a requested operation is blocked by Guard, report the block rather than attempting to bypass it.
