# AI guidance

## Repo purpose
Collection of custom Claude Code agent and skill definitions. Typical session: create or update agent or skill definitions

## Agent definitions
Strictly follow the Claude Code agent specification. If uncertain or spec may have changed, fetch current docs before writing any definition

Definitions live in `agents/<category>/`

Narrow, domain-specific agents (single language/framework, e.g. `dotnet-cs-expert`) live in `agents/<category>/specialists/` instead of flat under the category. Broad, general-purpose agents stay flat

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

## Skill definitions
Skills live in `skills/<skill-name>/SKILL.md`, one directory per skill, no category grouping. Follow the Claude Code skill specification; a skill's supporting files (scripts, references) are not version-tracked, only `SKILL.md`
No `color` field — that belongs to the agent spec, not the skill spec; do not carry it over when basing a new skill on an agent or another skill

## Versioning
On agent or skill definition update:
- Regenerate `.file-versions`: `{ find agents -name "*.md" -type f; find skills -name "SKILL.md" -type f; } | sort | xargs sha256sum > .file-versions`
- In `README.md`, bump the agent's or skill's version per the extent of the change, and sync the parenthesized hash next to it with the first 8 chars of the new hash