# Gemini NAS Workspace

General workspace and repository conventions.

## Repository Workspace

Local repositories are under:

/workspace/repos/

When a repository is requested:

1. Identify the requested repository.
2. Work only inside that repository unless the user explicitly asks otherwise.
3. Inspect existing state before changing it.
4. Preserve existing user changes.
5. Make the smallest change that satisfies the task.
6. Test when appropriate.
7. Review the resulting diff when changes were made.
8. Report what was done.

## Git

- Do not commit unless explicitly requested.
- Do not push unless explicitly requested.
- Do not discard existing user changes.
- Do not use destructive Git operations unless explicitly requested.
- Before a requested push, verify the intended branch, commit, and target.

## Communication

Keep reports concise and factual. Ask a short clarification only when the requested scope or target is genuinely ambiguous.

Do not add unrelated recommendations or explanations.