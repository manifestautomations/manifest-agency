# Technology Stack: Anti-Gravity Agent Manager Integration

**Project:** Manifest Automations v1.1 - Multi-Workspace Orchestration
**Researched:** 2026-01-29
**Mode:** Stack Analysis for Multi-Workspace Orchestration

---

## Executive Summary

Google Antigravity (released November 2025) provides the exact capabilities needed for v1.1: a unified Agent Manager interface with multi-workspace support, an Inbox for aggregated notifications, and native compatibility with existing Claude Code skills. The integration is straightforward because:

1. **Skills are portable** - Antigravity adopted the Agent Skills open standard; existing `.claude/skills/` work without modification
2. **Multi-directory support exists** - Both Antigravity and Claude Code support `--include-directories` / `--add-dir` for cross-workspace access
3. **Gemini orchestration aligns** - The hybrid Gemini+Claude workflow matches your existing orchestrator pattern

**Key finding:** You do NOT need to build cross-workspace communication infrastructure. Antigravity already provides it through the Agent Manager interface. Your job is integration, not invention.

---

## Recommended Stack Additions

### Core Platform

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Google Antigravity | Latest (public preview) | Primary development interface | Provides Agent Manager, Inbox aggregation, multi-workspace dispatch. Free during preview. |
| Gemini CLI | v0.23+ | Headless automation | Required for skills support; `--include-directories` enables cross-workspace file access |
| `agy` CLI | Latest | Terminal access to Antigravity | Allows scripted interaction without GUI; bridges existing bash scripts |

### Integration Layer

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| No new database | - | - | Agent Manager persists workspace state; existing `.worker/` structure sufficient |
| No new queue | - | - | Antigravity handles agent dispatch internally |
| No new notification system | - | - | Antigravity Inbox aggregates across workspaces natively |

### Existing Components (Keep As-Is)

| Component | Location | Integration Point |
|-----------|----------|-------------------|
| Worker execute | `scripts/worker/execute.sh` | Invoked by Antigravity agents via terminal |
| Dispatch system | `scripts/orchestrator/dispatch.sh` | Can be triggered from Agent Manager workflows |
| CEO Dashboard | `.claude/skills/ceo-dashboard/` | Converts to Antigravity skill, feeds Inbox |
| Agent manifests | `.claude/agents/*.yaml` | Reference for Antigravity agent configuration |
| Trust guardrails | `.claude/trust-guardrails.yaml` | Port to Antigravity execution policies |

**Confidence:** HIGH (Context7 + official documentation + community verification)

---

## How Antigravity Multi-Workspace Works

### Agent Manager Architecture

The Agent Manager is a "Mission Control" interface with three columns:
- **Left:** Project workspaces sidebar
- **Center:** Inbox - centralized conversation/notification history across all workspaces
- **Right:** Active work area

Key capabilities:
- Spawn up to 8 parallel agents in isolated workspaces simultaneously
- Each agent runs in its own workspace context
- Unified Inbox aggregates notifications from all agents
- Status indicators: "Idle", "Running", "Blocked"

### Workspace Communication Mechanisms

**Option 1: Multi-directory workspace (RECOMMENDED)**
```bash
# At session start, include child workspaces
gemini --include-directories /path/to/parent,/path/to/child-1,/path/to/child-2

# Or dynamically during session
/directory add /path/to/child-workspace
```
This creates a unified file context across all directories. Agents can read/write across boundaries within the same session.

**Option 2: Separate workspace agents with Inbox coordination**
Each child workspace is a separate Antigravity workspace. Parent orchestrator dispatches tasks, child agents post results to Inbox, parent aggregates.

**Recommendation:** Use Option 1 for v1.1. Option 2 adds complexity without clear benefit for your use case (related submodules).

### CLI Integration Pattern

```bash
# Headless execution (for existing scripts)
gemini -p "Execute issue #42 implementation" --output-format json

# With workspace context
gemini -p "Analyze dependency graph across workspaces" \
  --include-directories ./parent,./child-1,./child-2 \
  --output-format json

# Invoke from existing dispatch script
agy --workspace /path/to/child -p "Run worker for issue $ISSUE_NUMBER"
```

**Confidence:** HIGH (Gemini CLI documentation verified)

---

## Skills Portability

### Format Compatibility

Antigravity adopted the Agent Skills standard (same as Claude Code). Your existing skills work:

| Claude Code Location | Antigravity Location | Status |
|---------------------|---------------------|--------|
| `~/.claude/skills/` | `~/.agent/skills/` | Copy or symlink |
| `.claude/skills/` | `.agent/skills/` | Copy or symlink |
| `.claude/commands/` | Converted to skills | Auto-compatible |

### Migration Steps

1. **Symlink for dual-tool compatibility:**
   ```bash
   ln -s ~/.claude/skills ~/.agent/skills
   ln -s .claude/skills .agent/skills
   ```

2. **Update SKILL.md frontmatter (optional enhancements):**
   ```yaml
   ---
   name: worker-execute
   description: Execute GitHub issue work in isolated worktree
   # Antigravity-specific additions:
   context: fork  # Run in isolated sub-agent
   allowed-tools: Bash(./scripts/worker/*), Read, Write
   ---
   ```

3. **No code changes required** - Scripts in `scripts/` directory continue working

**Confidence:** HIGH (Cross-verified with community reports + official announcements)

---

## Integration with Existing Bash Scripts

### Current Scripts (Fully Compatible)

| Script | Invocation from Antigravity |
|--------|---------------------------|
| `scripts/orchestrator/dispatch.sh` | `bash scripts/orchestrator/dispatch.sh --issue 42` |
| `scripts/worker/execute.sh` | `bash scripts/worker/execute.sh --issue 42` |
| `scripts/github/*.sh` | Direct bash execution |

### Execution Policies Configuration

Antigravity allows configuring terminal execution policies:

```
Always Proceed: Auto-executes commands (with deny list)
Request Review: Requires approval before execution
Off: Blocks all commands unless explicitly allowed
```

**Recommendation:** Use "Request Review" initially, then transition to "Always Proceed" with deny list matching your existing `trust-guardrails.yaml`.

### Worker Trust Integration

Port your trust guardrails to Antigravity's execution policies:

```yaml
# Current: .claude/trust-guardrails.yaml
allow:
  - "Read"
  - "Bash(git status)"
deny:
  - "Bash(rm -rf:*)"
  - "Bash(git push --force:*)"

# Antigravity equivalent (in settings):
{
  "terminal": {
    "mode": "always_proceed",
    "deny_list": ["rm -rf", "git push --force", "git reset --hard"],
    "allow_list": ["./scripts/*", "git status", "gh *"]
  }
}
```

**Confidence:** MEDIUM (Execution policy configuration verified; exact mapping needs validation)

---

## Inbox Aggregation Strategy

### Current CEO Inbox Implementation

Your existing briefing system:
- `generate-briefing.sh` creates daily briefings
- `inbox-integration.sh` delivers to local file system
- Dashboard renders from `.worker/` data

### Antigravity Inbox Integration

Antigravity's Inbox already provides:
- Unified notification view across all workspaces
- Status badges (Running, Blocked, Complete)
- Click-through to workspace context

**Migration Path:**

1. **Phase 1: Parallel operation**
   - Keep existing briefing generation
   - Deliver to both local `.worker/inbox/` AND Antigravity Inbox
   - Use Antigravity Inbox as primary view

2. **Phase 2: Native integration**
   - Convert `generate-briefing.sh` to Antigravity skill
   - Use Antigravity artifacts for briefing display
   - Deprecate local inbox files

### Cross-Workspace Aggregation

For child workspace status aggregation:

```bash
# Option A: Multi-directory read (RECOMMENDED)
gemini -p "Aggregate status from all workspaces" \
  --include-directories ./manifest,./child-project-1,./child-project-2

# Option B: Sequential fetch
for workspace in ./child-*; do
  status=$(gemini -p "Get status" --cwd "$workspace" --output-format json)
  # aggregate
done
```

**Confidence:** MEDIUM (Architecture verified; specific aggregation patterns need implementation testing)

---

## What NOT to Add

| Tempting Addition | Why Skip It |
|-------------------|-------------|
| Custom IPC/message queue | Antigravity handles inter-agent communication |
| Database for workspace state | Agent Manager persists this; `.worker/` sufficient for audit |
| Custom notification service | Inbox provides this |
| New CLI tool | `agy` + `gemini` CLI sufficient |
| Websocket coordination layer | Overkill; file-based coordination with Antigravity orchestration sufficient |
| MCP server for cross-workspace | `--include-directories` solves this simpler |

**Rationale:** Antigravity already solved the hard problems (multi-agent orchestration, unified inbox, workspace isolation). Adding infrastructure duplicates what the platform provides.

---

## Potential Blockers

### 1. Windows Path Handling (MEDIUM risk)

Antigravity is cross-platform but may have edge cases:
- Git Bash path conversion (you already handle this in `execute.sh`)
- Symlink support varies

**Mitigation:** Test symlink strategy early; fall back to copy if needed.

### 2. Sandbox Restrictions (LOW risk)

Antigravity's restrictive sandbox profiles disable `/directory add` at runtime.

**Mitigation:** Use `--include-directories` at session start instead.

### 3. Rate Limits During Preview (LOW risk)

Free preview has "generous" but unspecified limits on Gemini 3 Pro.

**Mitigation:** Claude Code remains fallback for execution; use Gemini for orchestration only.

### 4. Skills Hot-Reload (RESOLVED)

Claude Code 2.1+ and Antigravity 1.14.2+ both support hot-reload. No session restart needed for skill changes.

---

## Version Compatibility Matrix

| Tool | Minimum Version | Feature Required |
|------|-----------------|------------------|
| Google Antigravity | 1.14.2+ | Skills support |
| Gemini CLI | 0.23+ | Full skills + `--include-directories` |
| Claude Code | 2.1.0+ | `--add-dir`, skills hot-reload |
| `agy` CLI | Latest | Terminal access to Antigravity |

---

## Installation Commands

```bash
# 1. Download Antigravity from antigravity.google
# Available for macOS, Windows, Linux

# 2. During setup, install agy CLI tool (option in setup flow)

# 3. Verify Gemini CLI version
gemini --version  # Should be 0.23+

# 4. Set up skills symlinks for dual-tool compatibility
ln -s ~/.claude/skills ~/.agent/skills
ln -s .claude/skills .agent/skills

# 5. (Windows alternative if symlinks fail)
# Copy skills instead:
# cp -r .claude/skills .agent/skills
```

---

## Sources

### Official Documentation
- [Google Developers Blog: Build with Antigravity](https://developers.googleblog.com/build-with-google-antigravity-our-new-agentic-development-platform/)
- [Google Codelabs: Getting Started with Antigravity](https://codelabs.developers.google.com/getting-started-google-antigravity)
- [Claude Code Docs: Skills](https://code.claude.com/docs/en/skills)
- [Gemini CLI Commands](https://geminicli.com/docs/cli/commands/)

### Community Verification
- [Claude Code Multi-directory Support Guide](https://claudelog.com/faqs/--add-dir/)
- [Antigravity Skills Integration](https://medium.com/@joe.njenga/google-antigravity-can-now-use-your-claude-code-skills-i-just-tested-new-agent-skills-7c5d33ca8c86)
- [GitHub: Gemini CLI Multi-Directory Issue #1118](https://github.com/google-gemini/gemini-cli/issues/1118)

### Security Considerations
- [Mindgard: Antigravity Cross-workspace Security](https://mindgard.ai/blog/google-antigravity-persistent-code-execution-vulnerability) - Review workspace trust boundaries

---

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| Antigravity Agent Manager | HIGH | Official docs + multiple community sources |
| Skills portability | HIGH | Verified standard adoption + community testing |
| Multi-directory workspace | HIGH | Gemini CLI docs + GitHub issues |
| Execution policy mapping | MEDIUM | Concept verified; exact config needs testing |
| Inbox aggregation | MEDIUM | Architecture clear; implementation details sparse |
| Windows compatibility | MEDIUM | Cross-platform claimed; Git Bash specifics unclear |

---

## Roadmap Implications

1. **Phase 1: Antigravity Setup** - Install, configure execution policies, symlink skills
2. **Phase 2: Single Workspace Validation** - Verify existing workflows work through Antigravity
3. **Phase 3: Multi-workspace Configuration** - Add child workspaces, test `--include-directories`
4. **Phase 4: Inbox Integration** - Connect briefing generation to Antigravity Inbox
5. **Phase 5: CEO Interface Migration** - Full transition to Agent Manager as primary interface

**Risk mitigation:** Keep Claude Code terminal as fallback; Antigravity is additive, not replacement.
