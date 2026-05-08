# AI guidance

## Repo purpose
Collection of custom Claude Code agent definitions. Typical session: create or update agent definitions

## Agent definitions
Strictly follow the Claude Code agent specification. If uncertain or spec may have changed, fetch current docs before writing any definition

Definitions live in `agents/<category>/`. Parallel text descriptions for programmatic regeneration live in `agent-descriptions/<category>/`

## Agent definition style rules
- spec compliance is critical: any broken frontmatter field, unknown key, or wrong format will silently prevent CC from loading or invoking the agent correctly; take extreme care
- `model` is always `inherit`
- `description` must be concise
- minimize blank lines, trailing periods
- `tools` list only what the agent actually needs
- colors by category
- no redundant concepts
- no memory; agents run stateless
- no bold formatting; backticks allowed where appropriate

## What to check before editing
- `README.md` has the full agent catalog with descriptions; keep it in sync after adding/removing agents
- `agent-descriptions/` mirrors `agents/` structure; update both when changing an agent