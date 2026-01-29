# External Integrations

**Analysis Date:** 2026-01-29

## APIs & External Services

**GitHub (Required):**
- Service: GitHub REST & GraphQL APIs
- What it's used for: Issue lifecycle management, PR creation, label-based state machine, project board updates, dependency tracking
- SDK/Client: GitHub CLI (`gh`) v2.x+
- Auth: OAuth token via `gh auth` (stored by gh CLI in local config)
- Endpoints used:
  - `gh issue create` - Create new issues with metadata
  - `gh issue edit` - Update labels, status
  - `gh issue comment` - Post plan comments and updates
  - `gh api graphql` - Complex queries (project updates, field values, item relationships)
  - `gh pr create` - Create pull requests after task completion
  - `gh repo view` - Get repository information

**Gemini API (Planned - Not Yet Implemented):**
- Service: Google Generative AI (Gemini 3 Pro Preview)
- What it's used for: Multi-agent orchestration, intent classification, task decomposition
- SDK/Client: `google-generativeai` Python library (planned)
- Auth: `GEMINI_API_KEY` environment variable
- Model: `gemini-3.0-pro-preview` (agentic orchestration optimized)
- Endpoints: REST API at `https://generativelanguage.googleapis.com/`

**LangSmith (Planned - Optional):**
- Service: LangChain observability platform
- What it's used for: Agent execution tracing, performance monitoring, latency analysis
- SDK/Client: LangSmith SDK (via LangGraph integration)
- Auth: `LANGSMITH_API_KEY` environment variable
- Purpose: Zero-overhead tracing for agent operations

## Data Storage

**Databases:**
- Not used in current implementation
- Planned: Redis 7.4+ for production deployment

**State/Coordination Storage:**
- **GitHub Issues & Labels** (Current):
  - Location: GitHub repository
  - Client: `gh` CLI
  - Purpose: Canonical source of truth for task state
  - State representation:
    - Labels: `worker:planning`, `worker:awaiting-approval`, `worker:executing`, `worker:complete`, `worker:failed`
    - Issue body: Summary, acceptance criteria, execution plan
    - Comments: Plan details, approval status, results

- **Local Filesystem** (Current):
  - Location: `.worker/` directory tree
  - Purpose: Temporary dispatch state, approvals, audit logs
  - Structure:
    - `.worker/dispatch/` - Dispatch JSONL logs and state
    - `.worker/agents/` - Agent status per active issue
    - `.worker/approvals/` - Pending/approved/denied approvals
    - `.worker/audit/` - Hash-chained audit trail (`chain.json`)
    - `.worker/logs/` - Execution logs

- **Redis** (Recommended - Not Yet Implemented):
  - Connection: `REDIS_URL=redis://localhost:6379`
  - Client: redis-py (Python) or @redis/client (TypeScript)
  - Purpose: Hot state access, agent coordination, sub-millisecond response times
  - Planned data structures:
    - Agent state snapshots (for LangGraph checkpointing)
    - Job queue for dispatch
    - Pub/sub for multi-agent messaging

**File Storage:**
- Local filesystem within git repository
- Worktrees for isolated task directories: `../manifest-automations-issue-N/`
- No cloud storage integration

**Caching:**
- Local file caching in `.worker/` for dispatch state
- GitHub project query cache (5-minute TTL mentioned in dashboard config)
- No distributed cache

## Authentication & Identity

**Auth Provider:**
- GitHub OAuth (via `gh` CLI)
- No separate identity provider

**Implementation:**
- GitHub CLI handles OAuth flow (`gh auth login`)
- Token stored locally by gh CLI in platform-specific config
- No application-level user authentication
- Trust levels replace user roles (defined in `.claude/settings.json`)

**Token Management:**
- Environment variable: `GITHUB_TOKEN` (fallback if `gh` not authenticated)
- Webhook secret: `GITHUB_WEBHOOK_SECRET` (for reactive GitHub events)

## Monitoring & Observability

**Error Tracking:**
- None currently implemented
- Errors logged to stderr and captured in `.worker/logs/`
- Structured audit trail in `.worker/audit/chain.json`

**Logs:**
- Shell script stderr redirection
- JSONL format logging to `.worker/dispatch/dispatch.jsonl`
- JSON audit events with hash chaining in `.worker/audit/chain.json`
- Planned: LangSmith integration for agent observability

**Metrics:**
- Manual aggregation via `scripts/orchestrator/aggregate.sh`
- Dashboard caching for live metrics (agents.running, agents.blocked, approvals.pending)
- No real-time metrics export

## CI/CD & Deployment

**Hosting:**
- Current: Local shell scripts on development machine
- Planned: Docker containers with docker-compose
- Eventual: Cloud deployment (AWS/GCP) with persistent orchestrator

**CI Pipeline:**
- None currently implemented
- Planned: GitHub Actions for:
  - Pre-receive hook enforcement (trust level validation)
  - Automatic test execution on PRs
  - Trust system enforcement before merge

**Deployment Mechanism:**
- Git push + GitHub CLI for coordination layer
- Worktree-based local execution for worker layer
- Manual shell command invocation or cron-based scheduling

## Environment Configuration

**Required env vars:**
- `GITHUB_TOKEN` or `gh auth` - GitHub API authentication
- `GEMINI_API_KEY` - Gemini orchestration (when implemented)
- `LANGSMITH_API_KEY` - LangSmith observability (when implemented)
- `REDIS_URL` - Redis connection string (when using Redis)

**Optional env vars:**
- `GITHUB_WEBHOOK_SECRET` - For webhook event validation
- `AGENT_TRUST_LEVEL` - Override default trust level per agent
- `AGENT_MODEL` - Override default Claude model
- `LANGSMITH_PROJECT` - Project name for LangSmith
- `OTEL_EXPORTER_OTLP_ENDPOINT` - OpenTelemetry collector endpoint

**Secrets location:**
- Local: GitHub CLI config (`~/.config/gh/` on Unix, `%AppData%\GitHub CLI\` on Windows)
- CI/CD: GitHub repository secrets (when using GitHub Actions)
- Production: Environment variables or secret management service

## Webhooks & Callbacks

**Incoming:**
- GitHub issue events (creation, label changes, comments)
- GitHub PR events (creation, approval, merge)
- Implementation: `.claude/skills/ceo-dashboard/` webhook listener (planned)

**Outgoing:**
- GitHub PR creation via `scripts/github/pr-create.sh`
- Issue label updates via `gh issue edit`
- Issue comments via `gh issue comment`
- Project board field updates via `gh api graphql`

## Rate Limiting & Quotas

**GitHub API:**
- Authenticated: 5000 requests/hour
- Unauthenticated: 60 requests/hour
- Mitigation:
  - `github_api_retry_attempts`: 3
  - `github_api_retry_delay_seconds`: 2
  - Rate limit detection and wait implemented in scripts

**Gemini API:**
- Planned: Rate limiting via LangGraph/LangChain
- Per-project quotas (when implemented)

**Redis:**
- No built-in rate limiting
- Planned: Manual quota management at application layer

## Error Handling & Resilience

**Retry Logic:**
- GitHub API: Exponential backoff with 3 attempts
- Worker execution: Crash recovery via stale lock detection (1800 second threshold)
- Dispatch: Automatic failure detection and cascade blocking

**Fallback Mechanisms:**
- Stale lock override with `--force` flag
- Async background worker execution when foreground unavailable
- GitHub label state machine survives script restarts

**Failure Detection:**
- Lock file timeout in `.worker/locks/issue-N.lock`
- GitHub label inspection for orphaned workers
- Audit trail hash verification for tamper detection

---

*Integration audit: 2026-01-29*
