export const CompactionControl = async () => ({
  "experimental.session.compacting": async (_input, output) => {
    output.prompt = `
Create a minimal continuation summary.

Rules:
- Preserve only information required to continue the user's task.
- Do not create Objective.
- Do not create Important Details.
- Do not create Work State.
- Do not create Next Move.
- Do not create Relevant Files.
- Do not instruct the agent to continue working.
- Return only the minimal factual context needed after compaction.
`
  },

  "experimental.compaction.autocontinue": async (_input, output) => {
    output.enabled = false
  },
})
