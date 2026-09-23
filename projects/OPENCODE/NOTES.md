# OpenCode — NOTES

## Current baseline

- OpenCode version: 1.18.32
- Binary: `/home/admin/.opencode/bin/opencode`
- Provider/model used for validation: `google/gemini-3.1-flash-lite`
- OpenCode is being run behind AI Guard.
- Gemini CLI is no longer the preferred execution path for this workflow.

## Problem observed

A simple prompt such as:

`Say exactly: OK`

could produce the expected `OK`, followed by an unwanted generated state block containing:

- Objective
- Important Details
- Work State
- Next Move
- Relevant Files

This happened in non-interactive `opencode run --format json` output as well, so it was not only a TUI rendering issue.

## Working plugin

The plugin at:

`adapters/opencode/plugins/compaction-control.ts`

uses OpenCode experimental hooks:

- `experimental.session.compacting` — replaces the compaction continuation prompt with a minimal factual summary.
- `experimental.compaction.autocontinue` — disables synthetic auto-continue after compaction.

The plugin explicitly prevents generation of the unwanted state-template sections.

## Validation

Test environment:

`/tmp/opencode-plugin-test/.opencode/plugins/compaction-control.ts`

### Normal response test

Prompt:

`Say exactly: OK`

Model:

`google/gemini-3.1-flash-lite`

Result:

- `OK` returned.
- No Objective / Important Details / Work State / Next Move / Relevant Files block observed.
- Step finished with `reason=stop`.

### Context-pressure test

A large test context was generated and supplied to OpenCode.

Result:

- File content was read successfully.
- OpenCode proceeded through multiple steps.
- Final response was exactly `COMPACTION-OK`.
- No unwanted state-template block appeared.
- No observed auto-continue loop.

Note: the JSON output did not expose an explicit named compaction event, so the exact firing of `experimental.session.compacting` is not independently proven by the output alone. The behavior is consistent with the intended compaction path; add temporary plugin logging if strict hook-level proof is required.

## Important OpenCode test detail

Do **not** use `--pure` when testing external plugins.

OpenCode reports:

`plugins: external plugins disabled (--pure)`

Therefore a `--pure` run cannot validate this plugin.

## AI Guard integration

The OpenCode adapter already provides:

- manual Google API-key selection
- persistent last-used-key state
- AI Guard sandbox execution
- SSH access through the Guard's read-only SSH credential mapping
- host-network mode when explicitly requested

The plugin itself must remain inside the OpenCode configuration/project boundary; do not expose the Guard installation or unrelated host paths merely to load it.

## Next step

1. Determine the correct persistent/global plugin discovery location for OpenCode 1.18.32.
2. Back up the relevant OpenCode configuration.
3. Install the plugin persistently.
4. Re-run the normal and context-pressure tests through AI Guard.
5. Run the complete AI Guard regression suite.
6. Keep the temporary `/tmp/opencode-plugin-test` copy only until production validation is complete.

## Security notes

- Never commit API keys, `auth.json`, SSH private keys, or other credentials.
- The plugin is behavior-control code, not an OS security boundary.
- AI Guard remains the external enforcement boundary.
- OpenCode should not be trusted to enforce host filesystem/network restrictions by itself.
