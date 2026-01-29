# Technology Stack

**Analysis Date:** 2026-01-29

## Languages

**Primary:**
- Bash (POSIX shell) - Core orchestration, worker dispatch, script infrastructure
- YAML - Configuration, agent manifests, trust guardrails

**Secondary:**
- JSON - Configuration files, status/audit data structures
- Markdown - Documentation, briefing templates, planning documents

## Runtime

**Environment:**
- Bash 4.3+ (for `wait -n` support in parallel dispatch)
- Git 2.43+ (for worktree support)
- GitHub CLI (gh) 2.x+ (primary API interface)

**Package Manager:**
- None (shell-based, external dependency via `gh` CLI)
- yq (YAML query tool, downloaded at runtime from GitHub releases)

## Frameworks

**Core:**
- GitHub - Coordination layer, issue/PR lifecycle, label-based state machine
- Git Worktree - Task isolation, parallel execution environment

**Orchestration:**
- Bash/Shell - Task dispatch, dependency graph resolution, parallel worker management
- LangGraph (recommended in planning but not yet implemented) - Multi-agent workflow

**Development/Operations:**
- pre-commit - Trust enforcement, local validation before commits

## Key Dependencies

**Critical:**
- GitHub CLI (`gh`) - All GitHub interactions (issues, PRs, labels, GraphQL queries, project management)
- Git (worktree, commit, push operations) - Version control, PR creation, branch management
- curl or wget - yq binary downloads, external tool installation

**Infrastructure:**
- Redis (recommended in planning) - State management, agent coordination, checkpointing
- Docker/Docker Compose (recommended) - Multi-agent local development, containerized execution

## Configuration

**Environment:**
- `.claude/settings.json` - Trust levels, permissions, workflow settings
- `.worker/config.json` - Worker timeouts, GitHub API retry logic, CEO interface settings
- `.claude/trust-guardrails.yaml` - Safety floor patterns, destructive operation rules, trust-level constraints

**Runtime Configuration Files:**
- `.env` - Required environment variables (not tracked, example format in planning docs)
- Agent manifests in `.claude/agents/` - YAML files with agent capabilities, constraints, tools

**Key Configuration Values:**
- `command_timeout_seconds`: 600 (10 min default for worker execution)
- `lock_staleness_threshold_seconds`: 1800 (30 min stale lock detection)
- `github_api_retry_attempts`: 3
- `MAX_CONCURRENT`: 3 (default concurrent worker limit)

## Platform Requirements

**Development:**
- Bash-compatible shell (bash 4.3+, zsh compatible)
- Git 2.43+ with worktree support
- GitHub CLI (gh) authenticated with `gh auth`
- curl or wget for tool downloads
- jq (JSON query tool, used in dispatch logging)
- yq (YAML query tool, auto-installed in worker scripts)

**Production:**
- Same shell/git requirements
- Redis 7.4+ for state management and coordination
- GitHub repository with API access
- cron or similar for scheduled orchestration (optional)

## External Services

**Required:**
- **GitHub** - Issue tracking, PR management, GraphQL API, project boards
  - Authentication: `gh` CLI (OAuth token stored locally)
  - Rate limits: 5000 req/hour authenticated, 60 req/hour unauthenticated

**Planned/Optional:**
- **Gemini API** (Google AI) - Orchestration decision making, intent classification
  - Environment variable: `GEMINI_API_KEY`
  - Model: Gemini 3 Pro Preview (agentic orchestration optimized)

- **LangSmith** (LangChain) - Agent observability, tracing
  - Environment variable: `LANGSMITH_API_KEY`
  - Purpose: Zero-overhead agent execution tracing

- **Redis** - Agent state, memory, multi-agent coordination
  - Connection: `REDIS_URL=redis://localhost:6379`
  - Purpose: Sub-millisecond hot state access, pub/sub messaging, checkpointing

## Build & Development Tools

**Build System:**
- None (shell-based, no compilation step)

**Code Quality:**
- ruff (Python linting, recommended for future Python layers)
- eslint (TypeScript linting, recommended for future TS layers)
- prettier (Code formatting)
- pre-commit (Git hook framework for enforcement)

**Testing:**
- pytest (Python, recommended for future orchestrator layer)
- Jest or Vitest (TypeScript, recommended for future GitHub integration layer)

**Observability:**
- Structured logging via jq/JSON to `.worker/audit/chain.json`
- Dispatch logging to `.worker/dispatch/dispatch.jsonl` (JSONL format)
- Built-in shell logging via stderr redirection

## Deployment Target

**Current:**
- GitHub repository (coordination layer)
- Local/development machine (shell script execution)

**Recommended Future:**
- Docker containers with compose orchestration
- Cloud deployment (AWS, GCP, or similar) for persistent orchestrator
- Redis cloud instance for state management
- GitHub Actions for CI/CD enforcement

---

*Stack analysis: 2026-01-29*
