# Agent Manifest Templates

Templates for creating new agent definitions.

## Quick Start

1. Copy `base.yaml` to `.claude/agents/<your-agent-name>.yaml`
2. Update the `name`, `version`, `author`, and `description`
3. Define the `tools` your agent needs
4. Set appropriate `constraints` (allow/deny patterns)
5. Add optional sections as needed

## Validation

Agent manifests are validated against `schemas/agent-manifest.schema.json`.

IDE Support: The `yaml-language-server` directive enables autocomplete and validation in VSCode with the YAML extension.

## Required Fields

- `name`: kebab-case identifier (3-50 chars)
- `version`: semantic version (e.g., 1.0.0)
- `tools`: array of tool names (at least one)

## Examples

See `.claude/agents/` for working examples:
- `code-reviewer.yaml` - Minimal agent with Claude extensions
- `backend-developer.yaml` - Full-featured agent with all options

## Schema Reference

Full schema documentation: `schemas/agent-manifest.schema.json`
