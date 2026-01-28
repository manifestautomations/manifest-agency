# Trust Guardrails

## Overview

The Trust Guardrails system provides automated safety controls for AI agent command execution. It enforces security policies, tracks trust levels, and maintains a tamper-proof audit trail of all agent actions.

**What guardrails do:**

- **Pre-hook blocking**: Validate commands before execution against safety patterns and trust levels
- **Post-hook auditing**: Log all command executions with cryptographic hash chaining
- **Scope enforcement**: Restrict agents to their declared allowed/denied command patterns
- **Trust progression**: Automatically adjust agent trust based on behavior (violations increase score, clean actions decrease it)
- **Incident recording**: Capture violations for forensic analysis and debugging

**Why they exist:**

- **Safety**: Prevent destructive operations (force push, rm -rf, permission changes)
- **Auditability**: Every action is logged with timestamps, agents, and outcomes
- **Trust progression**: Agents earn autonomy through demonstrated competence
- **Compliance**: Cryptographic proof of actions for security audits
- **Debugging**: Rich forensic data when things go wrong

---

## Quick Start

### Verify guardrails are working

```bash
# Check configuration
jq '.guardrails' .worker/config.json

# Verify audit chain integrity
scripts/worker/claude-audit.sh verify

# View trust scores
scripts/worker/claude-audit.sh trust-report

# List recent audit events
scripts/worker/claude-audit.sh list
```

### Basic workflow

1. Agent attempts to execute command
2. Pre-hook validates against:
   - Safety floor patterns (always blocked)
   - Trust level requirements
   - Agent-specific allow/deny patterns
3. If blocked: Logged, agent notified, violation recorded
4. If confirm needed: User prompted (TTY) or GitHub approval requested
5. If allowed: Command executes
6. Post-hook logs result and applies trust decay (-5 points for clean actions)

---

## Configuration

### Project-level (.claude/trust-guardrails.yaml)

The main guardrails configuration file defines patterns, severities, and trust requirements.

```yaml
# Safety floor - ALWAYS blocks regardless of trust level
safety_floor:
  - pattern: "^rm\\s+-rf\\s+/"
    severity: critical
    reason: "Root filesystem deletion"
```

**Sections:**

- `safety_floor`: Patterns that ALWAYS block (11 critical patterns including rm -rf, chmod 777, force push, etc.)
- `trust_requirements`: Commands that require minimum trust levels
  - Level 0: Complete lockdown (all commands blocked)
  - Level 1: Read-only operations
  - Level 2: Safe mutations (git commit, npm install)
  - Level 3: Moderate risk (git push, deployment)
  - Level 4: High risk (force operations, production changes)

**Severity levels:**

- `critical`: Irreversible, dangerous (score: 60 points)
- `high`: Risky but recoverable (score: 30 points)
- `medium`: Requires caution (score: 15 points)
- `low`: Minor concern (score: 5 points)

**How to add custom patterns:**

1. Edit `.claude/trust-guardrails.yaml`
2. Add pattern to appropriate section (safety_floor or trust_requirements)
3. Use regex format (escape special chars: `\s` for space, `\.` for dot)
4. Test with: `scripts/worker/claude-audit.sh explain "<command>"`

Example:

```yaml
trust_requirements:
  - pattern: "^kubectl\\s+delete"
    min_trust_level: 4
    severity: high
    reason: "Kubernetes resource deletion"
    alternatives: ["kubectl drain", "kubectl scale --replicas=0"]
```

### Agent manifests (constraints section)

Each agent manifest (`.claude/agents/*.yaml`) can define agent-specific patterns.

```yaml
constraints:
  allow:
    - pattern: "^npm\\s+(install|test|run)"
      reason: "Frontend package management"
  deny:
    - pattern: "^git\\s+push.*--force"
      reason: "Force push restricted for frontend agent"
```

**How allow/deny patterns work:**

1. Safety floor is checked first (always blocks)
2. Deny patterns are checked next (blocks if match)
3. Allow patterns are checked last (allows if match)
4. If no patterns match, default trust level rules apply

**Inheritance rules:**

- Agent-specific patterns override project-level trust requirements
- Safety floor is NEVER overridden
- Deny always wins over allow

**Examples:**

```yaml
# Backend developer - database access allowed
constraints:
  allow:
    - pattern: "^psql\\s+"
      reason: "Database queries"
    - pattern: "^docker\\s+compose"
      reason: "Local environment management"
  deny:
    - pattern: "^docker\\s+system\\s+prune.*-a"
      reason: "Prevents accidental image deletion"

# DevOps agent - deployment operations
constraints:
  allow:
    - pattern: "^kubectl\\s+"
      reason: "Kubernetes management"
    - pattern: "^terraform\\s+(plan|apply)"
      reason: "Infrastructure provisioning"
  deny:
    - pattern: "^terraform\\s+destroy"
      reason: "Requires manual approval"
```

### Worker config (.worker/config.json)

Runtime configuration for guardrails enforcement.

```json
{
  "guardrails": {
    "enabled": true,
    "default_trust_level": 2,
    "confirmation_timeout_seconds": 30,
    "violation_thresholds": {
      "warning": 20,
      "probation": 40,
      "demotion": 60
    },
    "decay_rate": 5,
    "audit_retention_days": 90
  }
}
```

**Settings:**

- `enabled`: Master switch (default: true)
- `default_trust_level`: Initial trust for new agents (0-4, default: 2)
- `confirmation_timeout_seconds`: Max wait for user approval (default: 30)
- `violation_thresholds`: Point values that trigger status changes
  - `warning`: 20 points (increased scrutiny)
  - `probation`: 40 points (restricted operations)
  - `demotion`: 60 points (trust level decreased)
- `decay_rate`: Points removed per clean action (default: -5)
- `audit_retention_days`: How long to keep audit logs (default: 90)

---

## Trust Levels

Trust levels control what commands an agent can execute autonomously.

| Level | Name       | Capabilities                         | Typical Use                   |
|-------|------------|--------------------------------------|-------------------------------|
| **0** | Lockdown   | All commands blocked                 | Compromised agent, debugging  |
| **1** | Read-only  | ls, cat, git status, etc.            | New agent, investigation      |
| **2** | Safe write | git commit, npm install, tests       | **Default** - most agents     |
| **3** | Moderate   | git push, deployments, DB migrations | Trusted agents                |
| **4** | Full       | Force operations, production changes | Senior agents, emergencies    |

### How trust is earned

- **Start**: All agents begin at level 2 (configurable via `default_trust_level`)
- **Earn**: Clean actions reduce violation score (-5 points per action)
- **Lose**: Violations increase score (5-60 points based on severity)
- **Promotion**: Manual promotion by project admin when agent demonstrates competence
- **Demotion**: Automatic when violation score exceeds 60 points

### How trust is lost

- **Violations**: Each blocked command adds points
  - Critical: +60 points (instant demotion)
  - High: +30 points
  - Medium: +15 points
  - Low: +5 points
- **Confirmation denials**: User rejects risky command (+15 points)
- **Command failures**: Repeated failures may indicate poor judgment

### Violation scoring and decay

**Scoring formula:**

```
new_score = current_score + violation_points - (clean_actions * decay_rate)
```

**Status thresholds:**

- `< 20`: Good standing (green)
- `20-39`: Warning (yellow) - increased monitoring
- `40-59`: Probation (orange) - restricted operations
- `≥ 60`: Demotion (red) - trust level decreased

**Decay mechanics:**

- Each successful command execution applies decay (-5 points by default)
- Decay does NOT apply if command was blocked or failed
- Minimum score is 0 (can't go negative)
- Decay rewards consistent good behavior

**Example progression:**

1. Agent starts: score 0, level 2
2. Violates medium rule: score 15, status good
3. Executes 3 clean commands: score 0 (15 - 15), status good
4. Violates critical rule: score 60, status demotion → level 1
5. Must execute 12 clean commands to return to good standing (60 / 5 = 12)

---

## Safety Floor

These patterns ALWAYS block, regardless of trust level or agent configuration.

| Pattern | Reason | Alternative |
|---------|--------|-------------|
| `^rm\s+-rf\s+/` | Root filesystem deletion | Specific paths only |
| `^chmod\s+777` | World-writable permissions | 755 or 644 |
| `^git\s+push.*--force` | Rewrite shared history | `--force-with-lease` |
| `^:\(\)\{.*:\&\}:` | Fork bomb | Don't |
| `^>\s*/dev/sd[a-z]` | Direct disk write | Use filesystem tools |
| `^dd\s+if=.*of=/dev/` | Overwrite devices | Specific device with confirmation |
| `^mkfs` | Format filesystem | Manual execution only |
| `^sudo\s+rm\s+-rf` | Root deletion with privileges | Never |
| `^curl.*\|\s*sh` | Execute remote code | Download, inspect, then run |
| `^wget.*\|\s*bash` | Execute remote code | Download, inspect, then run |
| `^eval\s+\$\(curl` | Remote code execution | Never |

**Why these are non-overridable:**

- Irreversible damage potential
- Security vulnerabilities
- Compliance requirements
- No legitimate automation use case

**What to do if you need to run a blocked command:**

1. **Manual execution**: Run outside worker context (direct terminal)
2. **Escalation**: Contact project admin to adjust pattern (if truly safe variant)
3. **Alternative**: Use safer alternative suggested by blocking message
4. **Workaround**: Break into multiple safer commands

---

## Audit Trail

All agent actions are logged to a tamper-proof audit trail.

### Where logs are stored

```
.worker/
├── audit/                      # Audit trail (hash-chained)
│   ├── YYYY-MM-DD.audit.jsonl # Daily log files
│   ├── chain.json             # Chain metadata
│   └── genesis.json           # Chain initialization
├── violations/                 # Violation records
│   ├── YYYY-MM-DD-violations.jsonl
│   └── incident-*.json        # Detailed incidents
└── trust-scores.json          # Current trust levels
```

### Hash chaining explanation

Each audit entry is cryptographically linked to the previous entry:

```
Entry N:
{
  "timestamp": "2026-01-28T12:00:00Z",
  "event_type": "command_executed",
  "agent": "backend-developer",
  "command": "git commit -m 'fix bug'",
  "previous_checksum": "abc123...",  # Hash of Entry N-1
  "checksum": "def456..."             # Hash of this entry
}
```

**Chain verification process:**

1. Read genesis checksum (64 zeros)
2. For each entry:
   - Verify `previous_checksum` matches previous entry's `checksum`
   - Recompute `checksum` from entry data
   - Verify computed hash matches stored hash
3. If any mismatch: Chain compromised

**Genesis checksum:**

- First entry's `previous_checksum` is 64 zeros
- Indicates chain start point
- Stored in `genesis.json`

### How to verify integrity

```bash
# Verify entire chain
scripts/worker/claude-audit.sh verify

# Output:
# Verifying audit chain integrity...
# ✓ Audit chain verification PASSED
#   All entries are cryptographically linked
#   No tampering detected
```

**If verification fails:**

1. Identify which entry broke the chain
2. Check file modification times (recent edit = suspect)
3. Investigate who had access to `.worker/audit/`
4. Restore from backup or GitHub history
5. Report security incident

### Retention policy

- **Audit logs**: Kept for 90 days (configurable)
- **Violation records**: Kept indefinitely
- **Trust scores**: Tracked in git (team visibility)
- **Chain metadata**: Permanent (for verification)

**Rotation:**

- Daily log files created (YYYY-MM-DD.audit.jsonl)
- Prevents single file growth
- Enables efficient date-based queries
- Old files automatically pruned after retention period

---

## Violation Handling

Violations are recorded when commands are blocked or denied.

### Severity levels

| Severity | Points | Example | Consequence |
|----------|--------|---------|-------------|
| Critical | 60 | `rm -rf /` | Instant demotion |
| High | 30 | `git push --force` | Probation after 2 violations |
| Medium | 15 | `chmod +x script` | Warning after 2 violations |
| Low | 5 | `npm publish` | Warning after 4 violations |

### Point values

Points accumulate in trust score:

```
trust_score = Σ(violations) - Σ(decay)
```

**Violation points:**

- Based on severity (5-60)
- Added immediately when command blocked
- Tracked per agent in `trust-scores.json`

**Decay points:**

- Subtracted per clean action (-5 default)
- Applied after successful command execution
- Never makes score negative

### Thresholds and consequences

| Score | Status | Effect |
|-------|--------|--------|
| 0-19 | Good | Normal operation |
| 20-39 | Warning | Increased logging, notify admin |
| 40-59 | Probation | Confirmation required for medium+ severity |
| 60+ | Demotion | Trust level decreased by 1 |

**Status effects:**

- **Good**: No restrictions
- **Warning**: Admin notified, extra scrutiny on commands
- **Probation**: Risky commands require user confirmation
- **Demotion**: Trust level decreased, more commands blocked

### How to recover from violations

1. **Execute clean commands**: Each successful command applies -5 decay
2. **Wait for threshold**: Score drops below threshold (e.g., 40 → 39 exits probation)
3. **Manual reset**: Admin can reset score in `trust-scores.json` if justified
4. **Promotion**: Admin can increase trust level to restore capabilities

**Example recovery:**

```bash
# Agent in probation (score: 45)
# Needs to execute 6 clean commands to exit probation
# 45 - (6 * 5) = 15 (below 40 threshold)

# View current status
scripts/worker/claude-audit.sh trust-report

# After clean executions
# Score decreases automatically
```

---

## CLI Reference (claude-audit)

The `claude-audit` tool provides query and analysis capabilities.

### Commands

#### list [agent] [since]

List audit events with optional filters.

```bash
# All events
scripts/worker/claude-audit.sh list

# Filter by agent
scripts/worker/claude-audit.sh list backend-developer

# Filter by date
scripts/worker/claude-audit.sh list "" 2026-01-28

# Both filters
scripts/worker/claude-audit.sh list frontend-developer 2026-01-27
```

**Output:**

```
TIMESTAMP            EVENT_TYPE         AGENT               COMMAND
2026-01-28T12:00:00Z command_allowed    backend-developer   git commit -m 'fix'
2026-01-28T12:01:00Z command_blocked    frontend-developer  rm -rf node_modules
```

#### violations [agent]

Show violation history.

```bash
# All violations
scripts/worker/claude-audit.sh violations

# Filter by agent
scripts/worker/claude-audit.sh violations backend-developer
```

**Output:**

```
TIMESTAMP            AGENT               SEVERITY  COMMAND              REASON
2026-01-28T12:00:00Z backend-developer   high      git push --force     Rewrite shared history
```

#### verify

Verify audit chain integrity.

```bash
scripts/worker/claude-audit.sh verify
```

**Output:**

```
Verifying audit chain integrity...

✓ Audit chain verification PASSED
  All entries are cryptographically linked
  No tampering detected
```

#### trust-report

Show trust scores for all agents.

```bash
scripts/worker/claude-audit.sh trust-report
```

**Output:**

```
Trust Report
============

AGENT               SCORE  STATUS      LAST_VIOLATION
backend-developer   15     good        2026-01-28T10:00:00Z
frontend-developer  45     probation   2026-01-28T11:30:00Z

Status codes:
  good       - Score < 20 (warning threshold)
  warning    - Score >= 20 and < 40
  probation  - Score >= 40 and < 60
  restricted - Score >= 60 (demotion threshold)
```

#### explain <command>

Explain why a command was blocked.

```bash
scripts/worker/claude-audit.sh explain "rm -rf /"
```

**Output:**

```
Blocked Command Explanation
===========================

Command:    rm -rf /
Timestamp:  2026-01-28T12:00:00Z
Agent:      backend-developer
Trust Level: 2
Severity:   critical
Reason:     Root filesystem deletion

This command was blocked by the trust guardrails system.
To execute this command, one of the following is required:
  1. Increase agent trust level
  2. Adjust guardrails configuration
  3. Execute manually outside worker context
```

#### incident <id>

Show detailed incident record.

```bash
scripts/worker/claude-audit.sh incident 20260128-001
```

**Output:**

```
Incident Details: 20260128-001
==============================

{
  "incident_id": "20260128-001",
  "timestamp": "2026-01-28T12:00:00Z",
  "agent": "backend-developer",
  "command": "git push --force",
  "severity": "high",
  "reason": "Rewrite shared history",
  "resolution": "pending"
}
```

#### timeline <issue>

Show chronological events for an issue.

```bash
scripts/worker/claude-audit.sh timeline 42
```

**Output:**

```
Timeline for Issue #42
============================

TIMESTAMP            EVENT_TYPE        DATA
2026-01-28T10:00:00Z worker_start      {"issue":42,"force":false}
2026-01-28T10:05:00Z execution_start   {"timestamp":1706443500}
2026-01-28T10:15:00Z execution_complete {"pr_number":123,"duration":"10m"}
```

### Common queries

```bash
# Recent violations
scripts/worker/claude-audit.sh violations | tail -10

# Trust status check
scripts/worker/claude-audit.sh trust-report

# Verify chain after suspicious activity
scripts/worker/claude-audit.sh verify

# Find why command was blocked
scripts/worker/claude-audit.sh explain "docker system prune -a"

# Issue execution timeline
scripts/worker/claude-audit.sh timeline 42

# Events for specific agent
scripts/worker/claude-audit.sh list backend-developer
```

---

## Troubleshooting

### "Command blocked but I need to run it"

**Options:**

1. **Manual execution**: Run outside worker context
   ```bash
   # Direct terminal execution (not through worker)
   git push --force-with-lease origin feature-branch
   ```

2. **Escalation**: Contact project admin
   - Request trust level increase (if appropriate)
   - Request guardrails pattern adjustment (if safe)

3. **Alternative**: Use safer variant
   ```bash
   # Blocked: git push --force
   # Alternative: git push --force-with-lease
   ```

4. **Workaround**: Break into safer steps
   ```bash
   # Blocked: rm -rf /
   # Workaround: rm -rf /specific/directory
   ```

### "Audit chain verification failed"

**Investigation steps:**

1. **Identify break point**:
   ```bash
   # Run verify with verbose output
   bash -x scripts/worker/claude-audit.sh verify
   ```

2. **Check file modification times**:
   ```bash
   ls -la .worker/audit/*.audit.jsonl
   # Recent unexpected modifications indicate tampering
   ```

3. **Review git history**:
   ```bash
   git log --oneline -- .worker/audit/
   # Should only show automated commits
   ```

4. **Restore from backup**:
   ```bash
   # From git (if chain.json is tracked)
   git checkout HEAD~1 .worker/audit/chain.json

   # From backup
   cp backup/chain.json .worker/audit/
   ```

5. **Report incident**:
   - Document timestamp of chain break
   - Identify affected entries
   - Notify security team
   - Review access logs

### "Trust score too high"

**How decay works:**

- Each successful command execution: -5 points
- Only clean actions apply decay
- Blocked/failed commands do NOT apply decay

**Waiting period:**

- Score 60 (demotion): Need 12 clean actions to return to good
- Score 45 (probation): Need 6 clean actions to exit probation
- Score 25 (warning): Need 2 clean actions to clear warning

**Manual reset (admin only):**

```bash
# Edit trust-scores.json
jq '.["agent-name"].score = 0' .worker/trust-scores.json > tmp.json
mv tmp.json .worker/trust-scores.json

# Commit change
git add .worker/trust-scores.json
git commit -m "admin: reset trust score for agent-name (justified reason)"
```

### "Confirmation timeout"

**TTY required:**

- Interactive prompts only work in terminal (TTY)
- GitHub Actions, cron jobs, etc. are non-TTY
- Non-TTY mode denies by default (safe)

**Solutions:**

1. **Increase trust level**: Avoid confirmation requirement
2. **Adjust pattern**: Remove or lower severity
3. **GitHub approval workflow**: Worker posts approval request to issue

---

## For Developers

### How to extend patterns

1. **Edit `.claude/trust-guardrails.yaml`**:
   ```yaml
   trust_requirements:
     - pattern: "^your-command-pattern"
       min_trust_level: 2
       severity: medium
       reason: "Your reason"
       alternatives: ["safer-command"]
   ```

2. **Test pattern**:
   ```bash
   # Source validator and test
   source .claude/skills/worker/lib/validator.sh
   validate_command "agent-name" 2 "your-command"
   ```

3. **Verify no false positives**:
   ```bash
   # Should NOT match safe variants
   validate_command "agent-name" 2 "similar-safe-command"
   ```

4. **Commit change**:
   ```bash
   git add .claude/trust-guardrails.yaml
   git commit -m "feat(guardrails): add pattern for your-command"
   ```

### Adding new validation rules

1. **Edit `.claude/skills/worker/lib/validator.sh`**
2. Add function to check new rule
3. Call from `validate_command` function
4. Add tests to verify behavior
5. Document in this file

### Integration points with worker

The worker integrates guardrails at these points:

1. **Initialization**: `init_audit_chain` (worker start)
2. **Configuration**: Load guardrail settings from config.json
3. **Execution**: (Currently placeholder - Phase 5 will add hook wrapping)
4. **Lifecycle logging**: Log worker_start, execution_start, execution_complete, execution_failed
5. **Completion**: Verify chain integrity (optional)

**Future enhancements (Phase 5+):**

- Wrap individual Claude tool calls (Bash, Write, Edit)
- Real-time command validation during agent execution
- Interactive approval via GitHub issue comments
- Automated trust level adjustments based on outcomes

---

*Last updated: 2026-01-28*
*Version: 1.0.0*
