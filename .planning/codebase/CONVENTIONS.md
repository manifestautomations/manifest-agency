# Coding Conventions

**Analysis Date:** 2026-01-31

## Naming Patterns

**Files:**
- Bash scripts: `kebab-case.sh` (e.g., `execute.sh`, `parser.sh`, `scope-validator.sh`)
- Library scripts: `noun.sh` suffix pattern (e.g., `logger.sh`, `validator.sh`, `audit.sh`)
- JSON data files: kebab-case with domain prefix (e.g., `issue-42-1234567890.jsonl`, `incident-20260127-235311-test-agent.json`)
- Markdown planning: `NN-CONTEXT.md`, `NN-RESEARCH.md`, `NN-01-PLAN.md`, `NN-02-SUMMARY.md` (e.g., `03-single-worker/03-01-PLAN.md`)
- Template files: domain-based (e.g., `summary.md`, `plan-comment.md`)

**Functions (Bash):**
- Private functions: `_prefix_name()` or no prefix, used internally within script
- Exported functions: PascalCase or snake_case, explicitly exported with `export -f`
- Library functions: snake_case (e.g., `parse_issue_body()`, `acquire_lock()`, `validate_command()`, `record_violation()`)
- Getter functions: prefix with `get_` (e.g., `get_trust_status()`, `get_staleness_threshold()`)

**Variables:**
- Global variables: UPPER_SNAKE_CASE (e.g., `LOCK_DIR`, `LOG_FILE`, `SESSION_ID`, `SCRIPT_DIR`, `REPO_ROOT`)
- Local variables: lower_snake_case (e.g., `issue`, `lock_metadata`, `threshold`, `current_score`)
- Configuration keys: lower_snake_case with dot notation in JSON (e.g., `command_timeout_seconds`, `lock_staleness_threshold_seconds`)
- Boolean flags: descriptive names without `is_` prefix (e.g., `FORCE_LOCK`, `STATUS_ONLY`, `allowed`, `found`)

**Directories:**
- Projects: kebab-case (e.g., `01-foundation`, `03-single-worker`, `06-worker-parallelization`)
- Infrastructure: dot-prefixed for framework (e.g., `.claude/`, `.worker/`, `.planning/`)
- Subdirectories: descriptive lowercase (e.g., `skills/`, `commands/`, `agents/`, `lib/`, `logs/`, `locks/`)

## Code Style

**Formatting:**
- Bash scripts use 2-space indentation (not tabs)
- Line length: No strict limit observed, but keep under 120 characters where practical
- No automatic formatter configured (no .prettierrc or eslint configs present)

**Bash Strict Mode:**
All production scripts use: `set -euo pipefail`
- `-e`: Exit on any error
- `-u`: Exit on undefined variable
- `-o pipefail`: Propagate pipe failures

**Comments:**
- Header comments: `# script-name.sh - One-line description`
- Usage comments: Provide usage examples in header
- Section comments: `# --- Section Name ---`
- Function comments: Include purpose, arguments, and returns
- Inline comments: Sparingly, for non-obvious logic

**String Quoting:**
- Always quote variables: `"$var"` not `$var`
- Use `$()` for command substitution, not backticks
- Use single quotes for literal strings: `echo '{"status": "ok"}'`
- Use double quotes for interpolation: `echo "Value: $var"`

## Import Organization

**Bash Script Dependencies:**
Scripts source library files in a specific order:

1. Core libraries first (from `.claude/skills/worker/lib/`):
   ```bash
   source "$LIB_DIR/logger.sh"
   source "$LIB_DIR/lock.sh"
   source "$LIB_DIR/parser.sh"
   source "$LIB_DIR/audit.sh"
   source "$LIB_DIR/validator.sh"
   source "$LIB_DIR/hooks.sh"
   ```

2. Extension libraries after core:
   ```bash
   source "$WORKER_SCRIPT_DIR/lib/graph-parser.sh"
   source "$WORKER_SCRIPT_DIR/spawn-subagent.sh"
   ```

3. Path preservation note: Save `SCRIPT_DIR` before sourcing libs that may overwrite it

**Path Aliases:**
- `REPO_ROOT` or `PROJECT_ROOT`: Repository root, computed as: `$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)`
- `SCRIPT_DIR`: Directory of current script, computed early before sourcing
- `LIB_DIR`: Library directory path, typically `.claude/skills/worker/lib/`
- `WORKER_DIR`: Worker infrastructure directory: `.worker/`

## Error Handling

**Patterns:**
- All scripts start with `set -euo pipefail` for automatic error propagation
- Explicit error checks for external commands: `if [ $? -ne 0 ]; then echo "[error]..."; return 1; fi`
- Use structured output for errors: `echo "[error] Description" >&2` (stderr)
- Return codes: 0 for success, 1 for failure
- No try-catch blocks (Bash doesn't support), instead use conditional checks

**Error Messages:**
- Format: `[error]` prefix for consistency
- Include context: command name, what failed, why, and suggestions when applicable
- Example: `[error] Worker already running for issue #${issue}` or `[error] Stale lock detected (${lock_age}s old, threshold: ${threshold}s)`

**Specific Error Types:**
- Validation errors: Return JSON with `{"action": "block", "severity": "...", "reason": "..."}`
- Trust violations: Return JSON with `{"status": "recorded", "new_score": ..., "threshold_status": "..."}`
- Parameter errors: Return JSON with `{"status": "error", "reason": "..."}`

## Logging

**Framework:** Custom JSON event logging system in `logger.sh`

**Patterns:**
- Initialize logging: `init_logging 42` (issue number)
- Log structured events: `log_event "event_type" --arg key value --arg key2 value2`
- Session lifecycle: `log_session_start` automatically on init, `log_session_end` on completion

**Log Format:**
- JSONL (JSON Lines): One JSON object per line
- Required fields: `timestamp` (ISO-8601), `event_type`, `event_id`, `session_id`, `data`
- File location: `.worker/logs/issue-${issue}-${timestamp}.jsonl`

**Common Event Types:**
- `session_start`: Worker begins processing
- `session_end`: Worker completes
- `error`: Error condition
- `validation_result`: Guard rail validation result
- `violation`: Trust violation recorded

## Comments

**When to Comment:**
- Complex conditional logic: Explain the reasoning
- Non-obvious bash idioms: Why this approach was chosen
- Important state transitions: What's changing and why
- Section breaks: Group related functionality

**JSDoc/TSDoc:**
Not applicable - codebase is bash scripts and markdown. Instead use inline bash function comments:

```bash
# Function name and one-line purpose
# Arguments: $1 description, $2 description
# Returns: exit code (0=success, 1=failure), may also echo JSON
function_name() {
  # Implementation
}
```

**Documentation Comment Convention:**
Functions that return JSON have explicit format documentation:
```bash
# Returns:
#   JSON: {action: "allow|block|confirm", severity, reason, alternatives[]}
```

## Function Design

**Size:** No strict limit observed, but files typically 80-600 lines per script

**Parameters:**
- Pass individual arguments: `function_name "$arg1" "$arg2"`
- Optional parameters: Use `${var:-default}` syntax
- Required parameters: Validate at function start, return error if missing
- JSON objects: Pass as jq expressions or JSON strings

**Return Values:**
- Exit code: 0 for success, 1 for failure
- Output on stdout: Typically JSON for structured data
- Errors on stderr: `echo "..." >&2`
- Side effects: Update global state (files, environment variables)

**Function Scope:**
- Functions at file level or after sourcing dependencies
- Private functions: Prefix with `_` if not exported
- Exported functions: Use `export -f function_name` at end of library file

## Module Design

**Exports:**
Library files explicitly export their public functions:
```bash
export -f load_guardrail_rules
export -f command_matches_pattern
export -f validate_command
# ... more exports
```

**Barrel Files:**
Not used in bash context. Each library file (`logger.sh`, `validator.sh`, etc.) is a distinct module sourced independently.

**Single Responsibility:**
Each library has clear focus:
- `logger.sh`: Event logging infrastructure
- `validator.sh`: Trust and command validation
- `parser.sh`: Issue body parsing
- `lock.sh`: Lock file management
- `audit.sh`: Cryptographic audit trail
- `hooks.sh`: Validation hooks for command execution

## Markdown Document Patterns

**Planning Documents:**
All phase plans follow YAML front matter with structure:
```yaml
---
phase: XX-phase-name
plan: NN
type: execute|research|verify
wave: N
depends_on: [list of dependencies]
files_modified: [list of files changed]
autonomous: true|false
---

<objective>
  Clear statement of what is being achieved
  Purpose: Why this matters
  Output: What the deliverable is
</objective>

<execution_context>
  @path/to/workflow.md
  @path/to/template.md
</execution_context>

<context>
  @path/to/context1.md
  @path/to/context2.md
</context>

<tasks>
  <task type="auto|manual">
    <name>Task 1: Name</name>
    <files>file-list</files>
    <action>Detailed action steps</action>
    <verify>How to verify completion</verify>
    <done>Completion statement</done>
  </task>
</tasks>
```

**Must-Haves Section:**
Documents include verification criteria:
```yaml
must_haves:
  truths:
    - "Fact 1"
  artifacts:
    - path: "file/path"
      provides: "Purpose"
      contains: "Key content"
  key_links:
    - from: "source"
      to: "target"
      via: "how connected"
      pattern: "matching pattern"
```

## Special Patterns

**JSON in Bash:**
- Construct JSON with `jq -n`: `jq -nc --arg key "value" '{key: $key}'`
- Parse JSON with `jq`: `echo "$json" | jq '.field'`
- Pass JSON objects to functions: As strings, parsed by jq in the function

**Trust System Variables:**
Scripts dealing with trust use consistent JSON structure:
```json
{
  "action": "allow|block|confirm",
  "severity": "critical|high|medium|low",
  "reason": "Human-readable explanation",
  "alternatives": []
}
```

**Issue Processing:**
GitHub issues have standardized structure parsed by `parser.sh`:
- `## Summary` section (required)
- `## Context` section
- `## Acceptance Criteria` section (required)
- `## Subtasks` section
- `## Dependencies` section
- `## Notes` section

---

*Convention analysis: 2026-01-31*
