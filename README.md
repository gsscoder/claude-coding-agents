# Coding Agents

A collection of specialized agents for [Claude Code](https://claude.com/claude-code), designed to enhance your AI-assisted development workflow with focused, expert capabilities.

## What are Custom Agents?
Custom agents are specialized AI assistants in Claude Code that focus on specific tasks. Each agent is optimized with:
- Tailored instructions for their domain
- Specific tool permissions
- Clear operational guidelines

## Which Agent to Install
Subagents run in isolated contexts, but their **metadata is loaded** into the parent context **at startup**, like other tools, adding some upfront token overhead at scale. For this reason, only include the subagents you actually need to avoid unnecessary context bloat.
It is preferable to **install them at the project level** to maintain tighter control over the context.

## Available Agents
**NOTE**: all agents have memory disabled.

### Code Navigation & Analysis
- **code-explorer** (haiku) - Intelligently locate and read files by path or role description using LSP for semantic navigation; extract specific code sections with surgical precision
- **code-analyst** (inherit) - Deeply understand how systems work by examining documentation, code, and related materials; trace implementation flows and clarify ambiguous specifications
- **forensics-analyst** (inherit) - Reverse-engineer unfamiliar codebases and understand the structure, behavior, and intent of code you didn't write; analyze only provided files without autonomous exploration

### Planning & Architecture
- **solution-architect** (opus) - Evaluate different implementation approaches and recommend optimal solutions for technical problems
- **design-reviewer** (opus) - Identify unnecessary complexity and over-engineered patterns in specific code components or architectural decisions
- **feature-planner** (opus) - Plan implementation changes for a submitted feature description; identify affected files, required changes, sequencing, and risks; can also review feature scope and codebase impact without planning implementation steps
- **task-planner** (inherit)- Analyze project state and develop strategic roadmaps for future development
- **task-completer** (inherit) - Systematically recover from failed tasks by learning from past attempts and identifying root causes

### Development & Implementation
- **task-builder** (inherit) - Implement development tasks from a single well-scoped step to a full feature translated from a design discussion, API spec, or documented requirement; declines requests with open design decisions remaining
- **change-executor** (inherit) - Execute a single, clearly scoped code modification (rename, value swap, signature adjustment, small addition/removal); declines requests that are too broad or require design decisions
- **code-fixer** (inherit) - Apply targeted, minimal corrections to resolve compile errors, type mismatches, logic bugs, and precise modifications without touching unrelated code
- **code-refactorer** (inherit) - Refactor code with surgical precision while maintaining exact functionality and minimizing disruption
- **code-simplifier** (inherit) - Reduce over-engineering, unnecessary abstractions, and accidental complexity while preserving identical behavior
- **frontend-builder** (inherit) - Modify or build frontend components, pages, layouts, and styles across any stack with surgical precision, applying UI changes exactly as described without scope expansion

### Testing & Quality
- **test-builder** (inherit) - Create comprehensive, well-reasoned test suites with clear traceability to requirements
- **test-designer** (inherit) - Design and implement tests that validate functionality, match existing patterns, and provide meaningful coverage
- **test-fixer** (inherit) - Identify and repair broken tests after code changes; on request can diagnose-only or fix the implementation code rather than tests

### Documentation & Maintenance
- **docs-maintainer** (inherit) - Keep documentation synchronized with code changes and architectural updates

## Installation
1. Clone this repository:
```bash
git clone https://github.com/gsscoder/claude-coding-agents.git
```

2. Copy the agent files you want to use into your Claude Code agents directory.

**Project-level** (available only within a specific project):
```bash
# Linux/macOS
cp ./agents/implement/* /path/to/your/project/.claude/agents/

# Windows
xcopy /e /i .\agents\implement\* C:\path\to\your\project\.claude\agents\
```

**User-level** (available across all projects):
```bash
# Linux/macOS
cp ./agents/implement/* ~/.claude/agents/

# Windows
xcopy /e /i .\agents\implement\* $home\.claude\agents\
```

## Usage
Agents are automatically invoked by Claude Code based on your requests and the task context. You can also explicitly request a specific agent:

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
