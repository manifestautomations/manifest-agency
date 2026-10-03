# External Integrations

**Analysis Date:** 2026-01-31

## APIs & External Services

**GitHub:**
- GitHub REST API v3 - Issue/PR/project management, label operations
  - SDK/Client: `gh` (GitHub CLI)
  - Auth: `GITHUB_TOKEN` environment variable
  - Endpoints used:
    - `POST /repos/{owner}/{repo}/issues` - Create issues
    - `PATCH /repos/{owner}/{repo}/issues/{issue}` - Edit issues, add labels
    - `GET /repos/{owner}/{repo}/issues/{issue}/comments` - Read issue comments
    - `POST /repos/{owner}/{repo}/issues/{issue}/comments` - Post comments
    - `GET /repos/{owner}/{repo}/projects` - Query projects
    - `POST /repos/{owner}/{repo}/pulls` - Create pull requests
- GitHub GraphQL API - Complex queries for projects and issue filtering
  - Used via: `gh api graphql`
  - Queries: Project item status, field values, custom properties

**Anthropic Claude:**
- Claude AI models - Executed via Claude Code interface
  - Integration: Worker scripts invoke `claude` CLI with prompts
  - Capabilities: Code generation, task planning, implementation
  - Invocation: `claude -p "$PROMPT" --allowedTools "Bash,Read,Write,Edit,Glob,Grep"`

## Data Storage

**Databases:**
- Local file system only
- No external database

**File Storage:**
- GitHub repositories (primary storage)
- Local `.worker/` directory structure:
  - `.worker/logs/` - JSONL execution logs
  - `.worker/dispatch/` - Dispatch state and events
  - `.worker/agents/` - Active agent registry
  - `.worker/approvals/` - Pending and approved items
  - `.worker/violations/` - Trust violations and incident records
  - `.worker/cache/` - Cached metrics and dashboard data
  - `.worker/audit/` - Audit chain and security events

**Caching:**
- In-memory via shell variables during script execution
- File-based cache in `.worker/cache/`:
  - `dashboard-cache.json` - 5-minute TTL for dashboard metrics
  - `portfolio-cache.json` - Portfolio status snapshots
- Cache invalidation: Via `--force` flag or TTL expiry

## Authentication & Identity

**Auth Provider:**
- Custom trust system (not external provider)
- Implementation: File-based trust levels (0-4) stored in `.planning/trust-ledger.md`
- GitHub authentication: GITHUB_TOKEN environment variable
- No external identity provider (OpenID, OAuth, SAML)

## Monitoring & Observability

**Error Tracking:**
- Internal structured logging system
- Logging framework: Custom bash logger in `scripts/.../lib/logger.sh`
- Log storage: JSONL files in `.worker/logs/`
  - Format: `issue-{issue_number}-{timestamp}.jsonl`
  - Events: worker_start, lock_failed, execution_start, etc.

**Logs:**
- Approach: Structured JSON event logging
- Output: `.worker/logs/issue-{N}-*.jsonl` files
- Log fields: timestamp, event_type, data object, agent_id
- Retention: No automatic cleanup (manual management)

**Audit Trail:**
- Audit chain stored in `.worker/audit/chain.json`
- Events logged: worker_start, execution_start, execution_complete, violations
- Fields: timestamp, agent, action, issue, rationale, outcome

**Violations & Trust:**
- Violation tracking: `.worker/violations/` directory
  - `trust-scores.json` - Current trust scores per agent
  - Incident files: `incident-{timestamp}-{agent}.json`
- Guardrails: Enforced at worker level via configuration

## CI/CD & Deployment

**Hosting:**
- GitHub (no separate deployment infrastructure)
- Execution: Local machine or GitHub Actions capable environment
- Artifacts: Pull requests, issue comments, GitHub projects

**CI Pipeline:**
- None detected - no traditional CI/CD
- Manual workflow: Human approval gates via issue comments
- Approval mechanism: GitHub reactions (👍) on plan comments

## Environment Configuration

**Required env vars:**
- `GITHUB_TOKEN` - GitHub API authentication (required for `gh` CLI)
- `AGENT_NAME` - Agent identifier (optional, defaults to "claude-worker")
- `AGENT_TRUST_LEVEL` - Trust level for metrics (optional, defaults to 2)
- `AGENT_MODEL` - Model name for PR metadata (optional, defaults to "claude-sonnet-4.5")

**Secrets location:**
- GitHub: GITHUB_TOKEN stored as GitHub Actions secret or user shell environment
- No .env file (security-sensitive)
- Trust system: Stored in checked-in `.planning/trust-ledger.md` (not secrets)

## Webhooks & Callbacks

**Incoming:**
- None detected - system is pull-based
- Manual triggers via command line or orchestrator

**Outgoing:**
- GitHub issue comments - Status updates and plan approval feedback
- GitHub PR creation - Work completion notifications
- GitHub label operations - Status and workflow state transitions

## Issue and Work Tracking

**Primary system:** GitHub Issues and Projects v2
- Issue body sections: Summary, Acceptance Criteria
- Labels: Priority (P0-P3), Complexity (XS-XL), Agent type, Phase, Status
- Project status fields: Ready, In Progress, In Review, Done
- Custom fields: Claimed By, Estimate, Phase Number

**Project structure:**
- Single GitHub Project (number 1 by default, configurable)
- Items filtered by: Status, Claimed By, Agent Type, Phase, Priority
- Query interface: `scripts/github/project-query.sh`

## Rate Limiting & Quotas

**GitHub API:**
- Rate limit: 5,000 requests/hour for authenticated requests
- Retry strategy: Up to 3 attempts with 2-second delay configured
- Wait handling: Up to 300-second wait for rate limit recovery

## Integration Flow

**Typical workflow:**
1. Human creates issue in GitHub (or via `scripts/github/issue-create.sh`)
2. Orchestrator queries project for Ready items via `project-query.sh`
3. Worker script (`scripts/worker/execute.sh`) claims issue and acquires lock
4. Worker parses issue body and generates execution plan
5. Plan posted as GitHub comment, awaits human approval
6. Human reacts with 👍 on plan comment
7. Worker invokes Claude Code CLI with implementation prompt
8. Claude implements changes, stages files
9. Worker creates commit with traced metadata
10. Worker creates PR with issue reference
11. PR closed automatically or via manual merge

---

*Integration audit: 2026-01-31*
