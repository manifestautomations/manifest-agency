# Coding Conventions

**Analysis Date:** 2026-01-29

## Overview

Manifest Automations uses a multi-paradigm approach combining shell scripts, YAML specifications, and structured markdown documentation. The codebase prioritizes clarity, atomicity, and auditability.

## Naming Patterns

**Files:**
- Shell scripts: `kebab-case.sh` (e.g., `worktree-create.sh`, `render-dashboard.sh`)
  - Library files grouped in `lib/` subdirectories: `logger.sh`, `parser.sh`, `lock.sh`
  - Executable scripts: start with `#!/usr/bin/env bash`
- Configuration files: kebab-case with file extension (e.g., `.gitattributes`, `.gitmodules`)
- YAML specifications: `agent-manifest.schema.json`, `*.yaml` for agent definitions
- Documentation: `UPPERCASE.md` for major docs (e.g., `PLAN.md`, `RESEARCH.md`, `SUMMARY.md`)
- Phase directories: `NN-description` format (e.g., `01-foundation`, `02-github-coordination`)

**Functions:**
- Shell functions: `snake_case` (e.g., `acquire_lock`, `log_event`, `extract_section`, `render_progress_bar`)
- Function documentation: inline comments above function definition explaining parameters and return values
- Example from `logger.sh`:
  ```bash
  # Log a structured JSON event
  # Arguments: event_type [--arg key value]...
  log_event() {
    ...
  }
  ```

**Variables:**
- Global shell variables: `UPPERCASE` (e.g., `LOCK_DIR`, `REPO_ROOT`, `LOG_FILE`)
- Local shell variables: `lowercase` (e.g., `issue`, `lock_age`, `threshold`)
- Exported environment variables: `UPPERCASE` (follows shell convention)
- JSON field names: `snake_case` (e.g., `issue_number`, `event_type`, `session_id`, `cache_age_seconds`)

**Types/Schemas:**
- Agent manifest files: `*.yaml` with schema reference at top: `yaml-language-server: $schema=../../schemas/agent-manifest.schema.json`
- JSON schemas: Located in `schemas/` directory with `.schema.json` extension
- Type definitions in YAML comments: Documented inline with field descriptions

## Code Style

**Shell Scripts:**

### Formatting
- Indentation: 2 spaces for readability
- Line length: Prefer under 100 characters, wrap long commands
- Comments: Use `#` for single-line, `# Comment` format (space after hash)
- Functions: Defined with `function_name() {` syntax, not `function function_name`

Example from `render-dashboard.sh`:
```bash
# Render ASCII progress bar (10 chars)
# Input: percent (0-100)
# Output: ASCII bar like "[========= ]"
render_progress_bar() {
  local percent="${1:-0}"
  ...
}
```

### Error Handling
- Start scripts with `set -euo pipefail` to catch errors immediately
- Functions return 0 on success, 1 on failure (shell convention)
- Echo errors to stderr (use `>&2` redirect for error messages)
- Example from `lock.sh`:
  ```bash
  set -euo pipefail

  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "[error] Failed to acquire lock" >&2
    return 1
  fi
  ```

### Quoting Rules
- Always quote variables: `"$variable"` not `$variable`
- Exception: Array expansion in specific contexts: `"${arg_flags[@]}"`
- Command substitution: `$(command)` not backticks
- Default values: `"${1:-default}"` for parameters

Example from `lock.sh`:
```bash
local issue="$1"
LOCK_DIR=".worker/locks/issue-${issue}.lock"
```

### Atomic Operations
- Use `mkdir` for atomic directory locking (works on NTFS/Windows)
- Use `jq` for JSON manipulation (not string parsing)
- Use absolute paths when possible for clarity in logs
- Document platform-specific considerations (e.g., MINGW64 behavior)

Example comment from `lock.sh`:
```bash
# NOTE: Uses mkdir for atomic locking (flock not available on Windows/MINGW64)
```

## Import Organization

**Shell Script Sourcing:**
- Order: Standard library → Project utilities → Configuration
- Use absolute or relative paths: `source "$LIB_DIR/logger.sh"`
- Check file existence before sourcing: `if [ -f "$file" ]`
- Example from `execute.md`:
  ```bash
  source "$LIB_DIR/logger.sh"
  source "$LIB_DIR/lock.sh"
  source "$LIB_DIR/parser.sh"
  ```

**JSON/jq Usage:**
- Output: `-r` for raw text, `-c` for compact
- Input: Use `--arg` or `--argjson` for data, never string concatenation
- Example from `logger.sh`:
  ```bash
  jq -nc \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg event_type "$event_type" \
    '{timestamp: $timestamp, event_type: $event_type}'
  ```

**YAML Agent Specifications:**
- Top-level keys: `name`, `version`, `author`, `description`
- Structured sections: `tools`, `dependencies`, `resources`, `execution`, `routing`, `constraints`
- Path references: Use glob patterns in constraints (e.g., `src/**`, `**/.env*`)

## Error Handling

**Strategy:** Fail fast with clear error messages

**Patterns:**

1. **Validation at Entry:**
   - Check required arguments immediately
   - Return 1 with error message to stderr
   - Example from `parser.sh`:
     ```bash
     if [ -z "$ISSUE_BODY" ] || [ "$ISSUE_BODY" = "null" ]; then
       echo "[error] Issue #${issue} has no body" >&2
       return 1
     fi
     ```

2. **Locked Section Pattern:**
   - Atomic directory creation for mutual exclusion
   - Check staleness before reporting failure
   - Document fallback with `--force` flag
   - From `lock.sh`:
     ```bash
     if ! mkdir "$LOCK_DIR" 2>/dev/null; then
       # Check staleness, allow force override
       if [ "$lock_age" -gt "$threshold" ] && [ "$force" = "true" ]; then
         rm -rf "$LOCK_DIR"
         mkdir "$LOCK_DIR"
       else
         return 1
       fi
     fi
     ```

3. **Signal Handling:**
   - Use trap for cleanup on EXIT, SIGTERM, SIGINT
   - Set state variable for context during interruption
   - Example from `execute.md`:
     ```bash
     WORKER_STATE="initializing"
     handle_signal() {
       if [ "$WORKER_STATE" = "executing" ]; then
         gh issue edit "$ISSUE_NUMBER" --add-label "worker:partial"
       fi
       exit 130
     }
     trap 'handle_signal SIGTERM' SIGTERM
     ```

## Logging

**Framework:** Structured JSON event logging via `logger.sh`

**Pattern:**
- Call `init_logging "$ISSUE_NUMBER"` once at script start
- Use `log_event "event_type" --arg key value --arg key2 value2` throughout
- Each event includes: timestamp, event_type, event_id, session_id, data
- Output: JSONL format (one JSON object per line) to `.worker/logs/issue-N-TIMESTAMP.jsonl`

Example from `logger.sh`:
```bash
log_event "plan_posted" --arg base_sha "$BASE_SHA"
log_event "execution_complete" \
  --arg pr_number "$PR_NUMBER" \
  --arg duration "$DURATION"
```

**Log Levels:** Not explicit, but indicated by event_type:
- `session_start`, `session_end` - Session lifecycle
- `error` - Error conditions
- `warning` - Non-blocking issues
- Domain-specific: `parse_failed`, `lock_failed`, `execution_start`, etc.

## Comments

**When to Comment:**
- Function signatures: Always include (purpose, arguments, return values)
- Complex logic: Explain the WHY, not the WHAT
- Non-obvious calculations: Document formula or assumptions
- Gotchas/platform quirks: Note Windows/Mac/Linux differences

**JSDoc/TSDoc:**
Not used (shell scripts don't have standardized doc format). Instead use inline comments above function definitions.

Example from `lock.sh`:
```bash
# Acquire lock for an issue
# Arguments: issue_number [force=false]
# Returns: 0 on success, 1 on failure
acquire_lock() {
  ...
}
```

**Inline Comments:**
- Document complex jq expressions
- Explain conditionals that aren't obvious
- Mark temporary workarounds with `# FIXME:` or `# TODO:`

From `render-dashboard.sh`:
```bash
# Calculate filled segments (out of 10)
local filled=$((percent / 10))
local empty=$((10 - filled))
```

## Function Design

**Size:** Keep functions focused and under 50 lines when possible

**Parameters:**
- Use positional arguments for required parameters
- Use optional flags for options (e.g., `--force`, `--output`)
- Quote all parameter expansion: `"$1"` not `$1`
- Provide defaults via parameter expansion: `"${1:-default}"`

**Return Values:**
- 0 = success, 1 = failure (POSIX convention)
- Use `echo` to return data (caller captures with `$()`)
- Multiple return values: Use JSON for complex returns
- Document return contract in function header

Example from `parser.sh`:
```bash
# Parse issue body and extract sections
# Arguments: issue_number
# Returns: 0 on success, 1 on failure
# Sets: ISSUE_* variables
parse_issue_body() {
  local issue="$1"
  ...
  return 0
}
```

## Module Design

**Exports:** Functions are the primary export unit

**Library Organization:**
- One concern per file: `logger.sh` handles logging only
- No global state mutation except initialization
- Libraries source other libraries if needed
- Example structure in `.claude/skills/worker/lib/`:
  - `logger.sh` - Event logging
  - `lock.sh` - Lock management
  - `parser.sh` - GitHub issue parsing
  - `validator.sh` - Input validation
  - `hooks.sh` - Custom action hooks
  - `audit.sh` - Audit trail management

**Barrel Files:**
Not used in shell (no concept of barrel/index files). Instead, include path is documented in skill files.

## Documentation

**Markdown Conventions:**

### File Structure
- Title: `# File Purpose` (one H1)
- Metadata block: YAML frontmatter or inline (date, version)
- Sections: H2 headers (`##`) for major sections
- Subsections: H3 headers (`###`) for details
- Code blocks: Use triple backticks with language identifier

### Planning Phase Documents
- `NN-RESEARCH.md` - Investigation findings
- `NN-XX-PLAN.md` - Detailed execution plan
- `NN-XX-SUMMARY.md` - Completion report
- `NN-CONTEXT.md` - Phase overview and dependencies
- `NN-VERIFICATION.md` - Success criteria

### Skill Documentation
- YAML frontmatter with `name`, `description`, `allowed-tools`, `context`
- H1 title matches skill name
- Execution section: How to run the skill
- State machine or workflow diagram if applicable
- Error handling section
- Integration points documented

Example from `.claude/skills/ceo-dashboard/SKILL.md`:
```yaml
---
name: dashboard
description: Show executive dashboard with agent status, trust health...
allowed-tools: Read, Bash
context: fork
---
```

## Platform-Specific Handling

**Windows/MINGW64:**
- Use `/` not `\` for paths in scripts
- Use `jq` for JSON (handles Windows line endings)
- Avoid `flock` (use `mkdir` for atomic locking)
- Absolute paths: Resolve via `$(pwd)` or git rev-parse

From `lock.sh`:
```bash
# NOTE: Uses mkdir for atomic locking (flock not available on Windows/MINGW64)
```

From `render-dashboard.sh`:
```bash
# Navigate to repo root (works on Windows + Unix)
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
if [ ! -d "$REPO_ROOT/.worker" ]; then
  REPO_ROOT="$(pwd)"
  while [ ! -d "$REPO_ROOT/.worker" ] && [ "$REPO_ROOT" != "/" ]; do
    REPO_ROOT="$(dirname "$REPO_ROOT")"
  done
fi
```

**Date/Time:**
- Use `date -u +"%Y-%m-%dT%H:%M:%SZ"` for UTC ISO8601
- Use `date +%s` for Unix timestamps
- Handle stat command differences: `stat -c %Y` (Linux) vs `stat -f %m` (macOS)

## Agent Specifications

**YAML Format:**
- Schema validation: Reference JSON schema at top with yaml-language-server directive
- Structure: Flat key-value pairs with nested objects for complex config
- Tools list: Strings of available tool names (e.g., `read_file`, `write_file`, `run_bash`)
- Constraints: `allow` and `deny` lists with glob patterns
- Routing: Priority number (0-100), tags for categorization

Example from `backend-developer.yaml`:
```yaml
# yaml-language-server: $schema=../../schemas/agent-manifest.schema.json
name: backend-developer
version: 1.0.0

tools:
  - read_file
  - write_file

constraints:
  allow:
    - "src/**"
    - "tests/**"
  deny:
    - "**/.env*"
```

## Commit Message Format

While not code conventions, documented in project for consistency:

- Title: Lowercase verb + noun (e.g., `docs: start milestone v1.1`)
- Body: Optional, detailed explanation of changes
- Co-author: `Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>` when applicable
- Scope: Optional, in brackets (e.g., `docs(07): complete phase`)

Example:
```
docs(07): complete CEO interface phase

- Documented all skills and workflows
- Created verification plan
- Updated milestone status

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

---

*Convention analysis: 2026-01-29*
