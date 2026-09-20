# AI Guard Notes

This is the top-level index for the lightweight external-memory layer.

## Project context

Project-specific AI context is kept under:

- `projects/NAS/`
- `projects/GEMINI/`
- `projects/TAPO-NAS/`

Use `NOTES.md` for stable facts and lessons. Use `RULES.md` only when a project has explicit AI instructions.

## Ownership

- AI Guard: shared AI context and enforcement.
- Project repositories: source of truth for code, tests, architecture, and detailed handoff.
- Runtime/workspace files on FnNAS: deployed copies of applicable instructions, when needed.

Avoid duplicating the same rule across projects.
