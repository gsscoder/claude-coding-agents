# Coding Agents
A collection of specialized agents for [Claude Code](https://claude.com/claude-code), designed to enhance AI-assisted development workflow with focused, expert capabilities.

## What are Custom Agents?
Custom agents are specialized AI assistants in Claude Code that focus on specific tasks. Each agent is optimized with:
- Tailored instructions for their domain
- Specific tool permissions
- Clear operational guidelines

## Repo Purpose
This repo was created to use at work the agents I built for my side projects. Initially, there weren’t many changes from the Claude Code scaffold, but over time I gradually learned more details — so yes, in part (though to a lesser extent) it’s also a learning project.
These are the more curated agents, sometimes created by merging overly specialized definitions into a single one:
- ✅ implement/**task-builder.md**
- ✅ implement/**frontend-builder.md**
- ✅ implement/**change-executor**
- ✅ implement/**code-fixer**
- ✅ testing-quality/**test-builder.md**
- ✅ testing-quality/**test-fixer**
- ✅ analysis/**forensics-analyst**

Once I’ve completed a thorough review of every agent, the list will be removed.

### What I’ve Learned
This is why agent definitions need refinement:
- Claude Code generates overly verbose descriptions in both content and YAML format, which is inefficient for context usage and useless when the **agent name** is explicitly specified in the prompt (ame and description metadata are loaded into the context at startup or with `/reload-plugins` command).
- The definition is **polluted with bold** and other text embellishments that only carry meaningful emphasis for **human readers**, without providing effective signals to the model.
- There are too many **blank lines** and **trailing periods** that could be removed to reduce token processing overhead.
- Some concepts are repeated with **excessive redundancy**.

## Which Agent to Install
Subagents run in isolated contexts, but their **metadata is loaded** into the parent context **at startup**, like other tools, adding some upfront token overhead at scale. For this reason, only include the subagents you actually need to avoid unnecessary context bloat.
It is preferable to **install them at the project level** to maintain tighter control over the context.

## Available Agents
**Common features**:
- Memory is disabled
- Model is set to `inherit`

### Code Navigation & Analysis
- **code-explorer** - Intelligently locate and read files by path or role description using LSP for semantic navigation; extract specific code sections with surgical precision.
- **code-analyst** - Deeply understand how systems work by examining documentation, code, and related materials; trace implementation flows and clarify ambiguous specifications.
- **forensics-analyst** - Reverse-engineer explicitly provided files to trace data flow, decipher legacy logic, analyze schema evolution, and explain unfamiliar inherited code; no broad codebase scanning or modification.

### Planning & Architecture
- **solution-architect** - Evaluate different implementation approaches and recommend optimal solutions for technical problems.
- **design-reviewer** - Identify unnecessary complexity and over-engineered patterns in specific code components or architectural decisions.
- **feature-planner** - Plan implementation changes for a submitted feature description; identify affected files, required changes, sequencing, and risks; can also review feature scope and codebase impact without planning implementation steps.
- **task-planner** - Analyze project state and develop strategic roadmaps for future development.
- **task-completer** - Systematically recover from failed tasks by learning from past attempts and identifying root causes

### Development & Implementation
- **task-builder** - Implement development tasks from a single well-scoped step to a full feature translated from a design discussion, API spec, or documented requirement; also handles rewrites and rebuild-style refactors where the replacement is decided; declines requests with open design decisions remaining.
- **change-executor** - Execute a single, clearly scoped code modification (rename, value swap, signature adjustment, small addition/removal); declines requests that are too broad or require design decisions.
- **code-fixer** - Apply targeted, minimal corrections to resolve compile errors, type mismatches, logic bugs, and precise modifications without touching unrelated code.
- **code-refactorer** - Refactor code with surgical precision while maintaining exact functionality and minimizing disruption.
- **code-simplifier** - Reduce over-engineering, unnecessary abstractions, and accidental complexity while preserving identical behavior.
- **frontend-builder** - Modify or build frontend components, pages, layouts, and styles across any stack with surgical precision; when building from scratch with design latitude, produces distinctive production-grade interfaces with a committed aesthetic direction.

### Testing & Quality
- **test-builder** - Design and implement spec-driven test suites with traceable assertions and systematic edge case coverage; can also produce spec-only coverage plans without writing code.
- **test-fixer** - Identify and repair broken tests after code changes; on request can diagnose-only or fix the implementation code rather than tests.

### Documentation & Maintenance
- **docs-maintainer** - Keep documentation synchronized with code changes and architectural updates.

## Installation
1. Install [scopy](https://github.com/gsscoder/super-copy):
```bash
npm install -g @koder0x/scopy@next
```

2. Register this repo as a source:
```bash
scopy source add cc-agents https://github.com/gsscoder/claude-coding-agents
```

3. Register your destination:
```bash
# Project-level
scopy dest add my-project /path/to/your/project/.claude/agents

# User-level
scopy dest add user-agents ~/.claude/agents
```

4. Sync the agents you want:
```bash
# All implement agents
scopy sync cc-agents/agents/implement my-project --force

# All testing & quality agents
scopy sync cc-agents/agents/testing-quality my-project --force

# Specific agent
scopy sync cc-agents/agents/planning-arch/task-completer.md my-project --force
```

## Usage
Even if agents may be automatically invoked by Claude Code based on your request and the task context, it is better to explicitly specify the agent in the prompt:
```
"Use the code-explorer agent to find all authentication files"
"I need the feature-builder agent to implement this spec"
```

## Notes
The `agent-descriptions/` directory contains text descriptions for each agent that are used to recreate the actual agent definitions. These descriptions can be used by Claude Code or other coding agentic tools to generate or update agent configurations programmatically.

## License
MIT License - feel free to use and modify these agents for your projects.

## Resources
- [Claude Code Documentation](https://code.claude.com/docs/en/overview)
