# Coding Agents

A curated collection of specialized agents for [Claude Code](https://claude.com/claude-code), designed to enhance your AI-assisted development workflow with focused, expert capabilities.

## What are Custom Agents?

Custom agents are specialized AI assistants in Claude Code that focus on specific tasks. Each agent is optimized with:
- Tailored instructions for their domain
- Specific tool permissions
- Optimized model selection
- Clear operational guidelines

## Available Agents

### Code Navigation & Analysis
- **code-explorer** - Intelligently locate and read files by path or role description, extract specific code sections with surgical precision
- **code-analyst** - Deeply understand how systems work by examining documentation, code, and related materials; trace implementation flows and clarify ambiguous specifications

### Development & Implementation
- **feature-builder** - Translate technical discussions and specs into production-ready code that aligns with existing architecture
- **code-refactorer** - Refactor code with surgical precision while maintaining exact functionality and minimizing disruption

### Quality & Testing
- **test-builder** - Create comprehensive, well-reasoned test suites with clear traceability to requirements
- **test-fixer** - Update broken tests after code changes to match new implementations
- **feature-reviewer** - Evaluate proposed changes and provide advisory recommendations for approval decisions

### Documentation & Maintenance
- **docs-maintainer** - Keep documentation synchronized with code changes and architectural updates

### Planning & Architecture
- **solution-architect** - Evaluate different implementation approaches and recommend optimal solutions for technical problems
- **task-planner** - Analyze project state and develop strategic roadmaps for future development
- **task-completer** - Systematically recover from failed tasks by learning from past attempts and identifying root causes

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/claude-coding-agents.git
```

2. Copy the agent files you want to use into your Claude Code agents directory:
```bash
# Linux/macOS
cp ./agents/*.md ~/.claude/agents/

# Windows
copy .\agents\*.md %USERPROFILE%\.claude\agents\
```

3. The agents will be available in Claude Code immediately

## Usage

Agents are automatically invoked by Claude Code based on your requests and the task context. You can also explicitly request a specific agent:

```
"Use the code-explorer agent to find all authentication files"
"I need the feature-builder agent to implement this spec"
```

## Customization

Each agent is defined in a markdown file with frontmatter. You can customize:
- `description` - When the agent should be used
- `tools` - Which Claude Code tools the agent can access
- `model` - Which Claude model to use (sonnet, opus, haiku)
- `color` - UI color coding

Edit the agent files to adapt them to your workflow and coding style.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - feel free to use and modify these agents for your projects.

## Resources

- [Claude Code Documentation](https://claude.com/claude-code)
- [Creating Custom Agents Guide](https://docs.anthropic.com/claude-code/agents)
