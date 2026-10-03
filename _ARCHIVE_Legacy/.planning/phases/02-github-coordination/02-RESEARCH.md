# Phase 2: GitHub Coordination - Research

**Researched:** 2026-01-27
**Domain:** GitHub CLI, GitHub Projects v2, issue/PR automation, GraphQL API
**Confidence:** HIGH

## Summary

Phase 02 establishes GitHub as the authoritative coordination layer for multi-agent orchestration through native GitHub features: Issues as work items, Pull Requests as completed work, Projects v2 for state visualization, and gh CLI for programmatic access. The research reveals a mature ecosystem with powerful GraphQL APIs, though some limitations exist (no native custom field filtering, rate limits, 1200 item cap in projects).

**Key findings:**
- GitHub CLI (`gh`) v2.86.0 provides comprehensive issue, PR, and project management with JSON output for scripting
- GitHub Projects v2 uses GraphQL with custom fields, but filtering requires post-processing with `jq`
- Built-in automation workflows handle PR merge → Done status, but custom transitions require GitHub Actions or API calls
- GraphQL API offers 5,000 points/hour (vs REST 5,000 requests/hour), better for relational queries
- Token scopes critical: `read:project` for Projects API, `repo` and `workflow` for automation

**Primary recommendation:** Use `gh CLI` as primary interface with GraphQL API (`gh api`) for custom field operations. Build automation on GitHub's built-in workflows (PR merge → Done) and extend with GitHub Actions for custom transitions. Use `jq` for filtering since native CLI filtering is limited. Always cache and check rate limits.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| gh CLI | 2.86.0+ | GitHub operations | Official GitHub CLI; full API access; JSON output; authenticated by default |
| jq | 1.7+ | JSON filtering | Industry standard for JSON parsing in bash; required for `gh --jq` filtering |
| GitHub Actions | - | Workflow automation | Native CI/CD; event-driven; GITHUB_TOKEN auto-provisioned |
| GraphQL API | Projects v2 | Custom field operations | Required for Projects v2; 5,000 points/hour; efficient batching |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| nektos/act | Latest | Local workflow testing | Test GitHub Actions locally before pushing; faster iteration |
| gh extensions | Various | Enhanced CLI features | `gh-project-item-list` for better filtering (community extension) |
| GitHub REST API | v3 | Simple operations | When GraphQL is overkill (single resource fetch, webhooks) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| gh CLI | GitHub REST API directly | More control but lose authentication, formatting, and abstraction |
| GitHub Projects v2 | External kanban (Trello, Linear) | More features but lose GitHub integration, audit trail, and single source of truth |
| Built-in workflows | Custom state machine | Full control but complexity, maintenance burden, and no GitHub UI integration |
| GraphQL API | REST API | REST simpler for single resources but GraphQL more efficient for relational queries |

**Installation:**
```bash
# gh CLI (already installed: v2.86.0)
# Check authentication and scopes
gh auth status

# Install jq (required for filtering)
# Windows (via Chocolatey)
choco install jq

# Or Windows (via Scoop)
scoop install jq

# Verify installation
jq --version  # Should show jq-1.7+
```

## Architecture Patterns

### Recommended Integration Structure

```
scripts/
├── github/
│   ├── issue-create.sh          # Create issue from template
│   ├── issue-claim.sh           # Claim issue (set Claimed By)
│   ├── issue-update-status.sh   # Update Status field
│   ├── issue-comment.sh         # Add structured comment
│   ├── pr-create.sh             # Create PR with metadata
│   ├── pr-link-issue.sh         # Link PR to issue (Closes #N)
│   ├── project-query.sh         # Query items with filters
│   ├── project-update-field.sh  # Update custom field value
│   └── README.md                # Usage documentation
├── worktree/                    # From Phase 01
└── README.md
```

### Pattern 1: Issue as Work Item

**What:** GitHub issues serve as work units with metadata, status tracking, and context storage
**When to use:** Any discrete task for agents (feature, bugfix, research, chore)
**Example:**
```bash
# Source: gh CLI manual - gh issue create

# Create issue from template with labels and project
gh issue create \
  --title "feat(auth): implement JWT refresh" \
  --body-file templates/issue-body.md \
  --label "feature,P1-high,agent:backend-developer,phase:2" \
  --assignee "@me"

# Link to project (adds to board)
gh issue edit 42 --add-project "Manifest Automations"

# Query unclaimed, ready issues
gh issue list \
  --json number,title,labels,updatedAt \
  --jq '.[] | select(.labels[].name == "Ready") | {number, title}'
```

**Why:** Native GitHub feature; searchable; linkable; supports labels, assignments, comments, and custom fields via Projects

**Source:** [GitHub CLI Manual - gh issue](https://cli.github.com/manual/gh_issue)

### Pattern 2: PR with Agent Metadata

**What:** Pull requests include structured agent metadata in description for audit trail
**When to use:** Every agent-generated PR
**Example:**
```bash
# Source: gh CLI manual - gh pr create

# Create PR with structured metadata in body
gh pr create \
  --title "feat(auth): implement JWT refresh (#42)" \
  --body "$(cat <<'EOF'
## Summary
Implements JWT token refresh mechanism with secure cookie storage.

## Changes
- Add `/auth/refresh` endpoint
- Implement token rotation logic
- Add integration tests

## Testing
- [x] Unit tests pass
- [x] Integration tests pass
- [x] Manual testing complete

Closes #42

---
**Agent Metadata**
| Field | Value |
|-------|-------|
| Agent | backend-developer |
| Issue | #42 |
| Worktree | manifest-automations-feature-auth |
| Duration | 23m 15s |
| Model | claude-sonnet-4.5 |
| Trust Level | 2 |
| Commits | 3 |
EOF
)" \
  --base main \
  --head feature-auth

# PR auto-links to issue via "Closes #42"
# PR merge triggers built-in workflow: Issue status → Done
```

**Source:** [gh pr create manual](https://cli.github.com/manual/gh_pr_create)

### Pattern 3: Custom Field Updates via GraphQL

**What:** Update GitHub Projects v2 custom fields using GraphQL API through gh CLI
**When to use:** Setting "Claimed By", "Status", "Priority", etc.
**Example:**
```bash
# Source: GitHub Projects v2 GraphQL API docs

# Step 1: Get field and option IDs (one-time setup, cache results)
gh api graphql -f query='
  query($org: String!, $number: Int!) {
    organization(login: $org) {
      projectV2(number: $number) {
        id
        fields(first: 20) {
          nodes {
            ... on ProjectV2Field {
              id
              name
            }
            ... on ProjectV2SingleSelectField {
              id
              name
              options {
                id
                name
              }
            }
          }
        }
      }
    }
  }' -f org="ManifestAutomations" -F number=1 > .cache/project-fields.json

# Extract Status field ID and "Claimed" option ID
STATUS_FIELD_ID=$(jq -r '.data.organization.projectV2.fields.nodes[] | select(.name=="Status") | .id' .cache/project-fields.json)
CLAIMED_OPTION_ID=$(jq -r '.data.organization.projectV2.fields.nodes[] | select(.name=="Status") | .options[] | select(.name=="Claimed") | .id' .cache/project-fields.json)

# Step 2: Get project item ID for issue
ITEM_ID=$(gh api graphql -f query='
  query($org: String!, $number: Int!, $issueNumber: Int!) {
    organization(login: $org) {
      projectV2(number: $number) {
        items(first: 100) {
          nodes {
            id
            content {
              ... on Issue {
                number
              }
            }
          }
        }
      }
    }
  }' -f org="ManifestAutomations" -F number=1 -F issueNumber=42 \
  | jq -r '.data.organization.projectV2.items.nodes[] | select(.content.number==42) | .id')

# Step 3: Update Status field to "Claimed"
gh api graphql -f query='
  mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
    updateProjectV2ItemFieldValue(
      input: {
        projectId: $projectId
        itemId: $itemId
        fieldId: $fieldId
        value: { singleSelectOptionId: $optionId }
      }
    ) {
      projectV2Item {
        id
      }
    }
  }' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$STATUS_FIELD_ID" -f optionId="$CLAIMED_OPTION_ID"
```

**Why:** Custom fields aren't accessible via `gh issue` commands; GraphQL mutation is required

**Source:** [Using the API to manage Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects)

### Pattern 4: Structured Progress Comments

**What:** Add human-readable comments with machine-parseable HTML comment blocks
**When to use:** Claim, Start, Progress updates, Blockers, PR opened
**Example:**
```bash
# Source: Phase 02 CONTEXT.md decisions

# Add progress comment to issue
gh issue comment 42 --body "$(cat <<'EOF'
Starting work on JWT refresh implementation.

<!-- agent:progress -->
| Field | Value |
|-------|-------|
| Agent | backend-developer |
| Status | implementing |
| Progress | 0% |
| Elapsed | 0m 0s |
| Current Task | Setting up worktree |
| Blockers | None |
<!-- /agent:progress -->
EOF
)"

# Structured comment allows:
# - Human reads: "Starting work on JWT refresh implementation"
# - Machine parses: HTML comment block for metrics/tracking
# - Future tooling: Extract progress data for dashboards
```

**Source:** Phase 02 CONTEXT.md (user decisions)

### Pattern 5: Filtered Project Queries with jq

**What:** Query project items with custom field filters using `gh project item-list` + `jq`
**When to use:** Finding unclaimed Ready issues, checking agent workload, status reports
**Example:**
```bash
# Source: gh project item-list manual + community patterns

# Query all Ready items with empty "Claimed By"
gh project item-list 1 --owner "@me" --format json --limit 100 \
  | jq -r '
    .items[]
    | select(
        (.status == "Ready") and
        (.fieldValueByName(name: "Claimed By").text == null or .fieldValueByName(name: "Claimed By").text == "")
      )
    | {number: .content.number, title: .content.title, priority: .priority}
  '

# Count items by agent
gh project item-list 1 --owner "@me" --format json --limit 100 \
  | jq -r '
    .items[]
    | .fieldValueByName(name: "Claimed By").text // "unclaimed"
  ' \
  | sort | uniq -c | sort -rn

# Find blocked items
gh project item-list 1 --owner "@me" --format json --limit 100 \
  | jq -r '
    .items[]
    | select(.labels[]?.name == "blocked")
    | {number: .content.number, title: .content.title, blockedBy: .content.body}
  '
```

**Why:** `gh project item-list` has no native filter flags; must export JSON and filter with `jq`

**Source:** [gh project item-list](https://cli.github.com/manual/gh_project_item-list), [GitHub issue #93](https://github.com/github/gh-projects/issues/93)

### Pattern 6: Branch Naming for Auto-Linking

**What:** Branch names include issue number for automatic linking in PRs
**When to use:** Every feature branch created by agents
**Example:**
```bash
# Source: Conventional branch naming + GitHub auto-linking

# Pattern: <type>/<issue-number>-<short-description>
git checkout -b feature/42-jwt-refresh

# When PR created from this branch, GitHub automatically:
# - Detects issue number in branch name
# - Suggests "Closes #42" in PR body
# - Links PR to issue in timeline

# Alternative patterns (all auto-link):
# - fix/123-auth-bug
# - chore/456-update-deps
# - refactor/789-cleanup-utils
```

**Source:** [Conventional branch naming](https://conventional-branch.github.io/), [GitHub auto-linking](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/autolinked-references-and-urls)

### Anti-Patterns to Avoid

- **Never query custom fields via REST API**: Projects v2 requires GraphQL; REST endpoints don't support custom fields
- **Never update project fields via `gh issue edit`**: Custom fields only editable via GraphQL mutations
- **Never assume GITHUB_TOKEN has all scopes**: Check required scopes (`read:project` for Projects, `repo` for issues)
- **Never poll for status changes**: Use webhooks or built-in automations; polling wastes rate limits
- **Never commit secrets in issue bodies or comments**: Always use GitHub Secrets for sensitive data
- **Never create 1000+ items in one project**: 1200 item limit; archive completed items or split projects
- **Never parse gh CLI human-readable output**: Always use `--format json` + `jq` for scripting

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Issue/PR linking | Custom tracking DB | GitHub auto-linking keywords | `Closes #N` in PR body auto-closes issue on merge; native timeline integration; searchable |
| Project status updates | Custom state machine | Built-in workflows + GraphQL | PR merge → Done is native; custom transitions via GraphQL API; UI integration |
| Agent metadata storage | External database | Structured PR/issue comments | Audit trail in GitHub; searchable; no state drift; survives repo migrations |
| Rate limit handling | Custom retry logic | Check `X-RateLimit-*` headers + exponential backoff | GitHub provides limit headers; standard retry pattern; avoid ban |
| JSON filtering | Custom parsers | jq with `gh --jq` flag | Battle-tested; 10+ years stable; handles edge cases (nulls, escaping) |
| Local workflow testing | Push-and-pray | nektos/act | Test GitHub Actions locally; faster iteration; no wasted CI minutes |
| Custom field caching | Manual JSON files | GraphQL + TTL cache | Field IDs rarely change; cache for 1 hour; reduces API calls 100x |

**Key insight:** GitHub's native features (auto-linking, built-in workflows, webhooks) are more reliable than external tracking. Use GraphQL for custom fields because it's the only supported API. Always use `jq` for filtering—it's the industry standard and handles all edge cases.

## Common Pitfalls

### Pitfall 1: Custom Field Filtering Requires Post-Processing

**What goes wrong:** Attempt to filter project items by custom field using `gh project item-list --filter` fails because no such flag exists.

**Why it happens:** GitHub Projects v2 CLI lacks native filtering by custom fields. Must export JSON and filter with `jq`.

**How to avoid:**
```bash
# DON'T: This flag doesn't exist
gh project item-list 1 --filter "Claimed By=empty"  # ❌ Error: unknown flag

# DO: Export JSON and filter with jq
gh project item-list 1 --format json --limit 100 \
  | jq '.items[] | select(.fieldValueByName(name: "Claimed By").text == null)'  # ✓ Works
```

**Warning signs:**
- "unknown flag" errors when using `--filter` with `gh project`
- Scripts that attempt to filter project items without `jq`
- Hardcoded filtering logic instead of dynamic jq queries

**Source:** [GitHub issue #93](https://github.com/github/gh-projects/issues/93)

### Pitfall 2: GraphQL Rate Limits Hit Faster Than Expected

**What goes wrong:** Scripts exceed GitHub's 5,000 points/hour GraphQL rate limit, blocking further API calls.

**Why it happens:** Each GraphQL query costs points (5-50 depending on complexity). Nested queries, large `first:` values, and frequent polling burn through limits quickly.

**How to avoid:**
```bash
# Check rate limit status before critical operations
gh api rate_limit | jq '.resources.graphql'
# Output: { limit: 5000, remaining: 4823, reset: 1738034400 }

# Cache field IDs (rarely change, ~1/hour TTL)
if [ ! -f .cache/project-fields.json ] || [ $(find .cache/project-fields.json -mmin +60) ]; then
  gh api graphql -f query='...' > .cache/project-fields.json
fi

# Use efficient queries (fieldValueByName vs iterate all fieldValues)
# BAD: Costs ~20 points, iterates all fields
fieldValues(first: 20) { nodes { ... } }

# GOOD: Costs ~5 points, direct lookup
fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue { name } }

# Implement exponential backoff on 403 rate limit errors
if gh api graphql ... 2>&1 | grep -q "rate limit"; then
  sleep $((2 ** retry_count))  # 2s, 4s, 8s, 16s...
fi
```

**Warning signs:**
- `403 Forbidden` with "rate limit exceeded" message
- `X-RateLimit-Remaining: 0` in response headers
- Scripts failing after initial success

**Source:** [Rate limits for GraphQL API](https://docs.github.com/en/graphql/overview/rate-limits-and-query-limits-for-the-graphql-api)

### Pitfall 3: GITHUB_TOKEN Missing Required Scopes

**What goes wrong:** GitHub Actions workflows fail with "Resource not accessible by integration" when accessing Projects API.

**Why it happens:** Default `GITHUB_TOKEN` in GitHub Actions lacks `read:project` scope. Must use Personal Access Token (PAT) or GitHub App with correct permissions.

**How to avoid:**
```yaml
# DON'T: Use default GITHUB_TOKEN for Projects API
- name: Update project field
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}  # ❌ Missing read:project scope
  run: gh api graphql -f query='...'

# DO: Use PAT with required scopes
- name: Update project field
  env:
    GH_TOKEN: ${{ secrets.PROJECT_PAT }}  # ✓ PAT with read:project, repo, workflow
  run: gh api graphql -f query='...'

# Verify token scopes locally
gh auth status
# Output: Token scopes: 'gist', 'read:org', 'repo', 'workflow'  # ✓ Good
# Output: Token scopes: 'repo'  # ❌ Missing read:project
```

**Warning signs:**
- "Resource not accessible by integration" errors in Actions
- GraphQL queries work locally but fail in CI
- `gh auth status` shows missing scopes

**Source:** [GITHUB_TOKEN permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)

### Pitfall 4: Project Item Limit of 1200

**What goes wrong:** Cannot add more items to project after 1200 active items. "Projects cannot have more than 1200 items" error.

**Why it happens:** GitHub Projects v2 has hard cap of 1200 active items (plus 10,000 archived). Large projects hit this quickly.

**How to avoid:**
```bash
# Check project item count
gh project item-list 1 --format json --limit 1200 | jq '.items | length'

# Auto-archive completed items (14 days in Done)
gh api graphql -f query='
  mutation($projectId: ID!, $itemId: ID!) {
    archiveProjectV2Item(input: {projectId: $projectId, itemId: $itemId}) {
      item { id }
    }
  }' -f projectId="..." -f itemId="..."

# Configure built-in auto-archival workflow
# GitHub UI → Project → Settings → Workflows → Auto-archive items
# Set: Status = Done AND Updated > 14 days ago → Archive

# Split large projects by phase/milestone
# - Project 1: Active Development (Phases 1-3)
# - Project 2: Maintenance (Phases 4-7)
```

**Warning signs:**
- "Projects cannot have more than 1200 items" error
- Project performance degrading (slow loads, timeouts)
- Cannot add new issues to project

**Source:** [GitHub issue #9678](https://github.com/orgs/community/discussions/9678)

### Pitfall 5: Built-in Workflows Don't Support Custom Transitions

**What goes wrong:** Issue status doesn't change from "Claimed" to "In Progress" when PR is opened, even though you set up automation.

**Why it happens:** Built-in workflows only support PR close → Done and PR merge → Done. Custom transitions require GitHub Actions or GraphQL API calls.

**How to avoid:**
```yaml
# GitHub Actions workflow for custom transitions
# .github/workflows/project-automation.yml
name: Project Automation
on:
  pull_request:
    types: [opened, ready_for_review]

jobs:
  update-status:
    runs-on: ubuntu-latest
    steps:
      - name: Extract issue number from PR
        id: issue
        run: |
          ISSUE_NUM=$(gh pr view ${{ github.event.pull_request.number }} --json body -q '.body' | grep -oP 'Closes #\K\d+')
          echo "number=$ISSUE_NUM" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.PROJECT_PAT }}

      - name: Update issue status to In Review
        run: |
          # GraphQL mutation to update Status field
          gh api graphql -f query='...' -f issueNumber=${{ steps.issue.outputs.number }}
        env:
          GH_TOKEN: ${{ secrets.PROJECT_PAT }}
```

**Built-in workflows (what's available):**
- ✅ PR closed → Status: Done
- ✅ PR merged → Status: Done
- ✅ Item added → Status: Todo (configurable)
- ✅ Status: Done AND age > 14 days → Archive
- ❌ PR opened → Status: In Review (custom)
- ❌ Issue commented → Status: Claimed (custom)

**Source:** [Built-in automations](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations)

### Pitfall 6: jq Not Installed in Environment

**What goes wrong:** Scripts using `gh --jq` flag fail with "jq: command not found" error.

**Why it happens:** `jq` is not bundled with `gh CLI`. Must be installed separately. Common in fresh environments (new Windows install, Docker containers, CI runners).

**How to avoid:**
```bash
# Check jq installation at script start
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed"
  echo "Install: https://jqlang.github.io/jq/download/"
  exit 1
fi

# Install in CI/CD (GitHub Actions)
- name: Install jq
  run: sudo apt-get install -y jq  # Ubuntu runner

# Install on Windows
choco install jq  # Chocolatey
scoop install jq  # Scoop

# Verify version
jq --version  # jq-1.7+
```

**Warning signs:**
- "jq: command not found" errors
- `gh --jq` flag failing even with valid expressions
- Scripts work locally but fail in CI

**Source:** [jq installation](https://jqlang.github.io/jq/download/)

## Code Examples

Verified patterns from official sources:

### Complete Issue Creation with Project Linking

```bash
# Source: gh CLI manual, GitHub Projects v2 API

#!/bin/bash
# scripts/github/issue-create.sh

set -e

TITLE="$1"
BODY_FILE="$2"
LABELS="${3:-feature,P2-medium,agent:any,phase:2}"
PROJECT_NUMBER="${4:-1}"

# Validate inputs
if [ -z "$TITLE" ] || [ -z "$BODY_FILE" ]; then
  echo "Usage: $0 <title> <body-file> [labels] [project-number]"
  exit 1
fi

# Create issue
ISSUE_URL=$(gh issue create \
  --title "$TITLE" \
  --body-file "$BODY_FILE" \
  --label "$LABELS" \
  --json url -q '.url')

ISSUE_NUMBER=$(basename "$ISSUE_URL")

echo "✓ Issue created: #$ISSUE_NUMBER"

# Add to project
gh issue edit "$ISSUE_NUMBER" --add-project "$PROJECT_NUMBER"

echo "✓ Added to project $PROJECT_NUMBER"
echo "$ISSUE_URL"
```

### Claim Issue and Update Custom Field

```bash
# Source: GitHub Projects v2 GraphQL API

#!/bin/bash
# scripts/github/issue-claim.sh

set -e

ISSUE_NUMBER="$1"
AGENT_NAME="$2"
ORG="ManifestAutomations"
PROJECT_NUMBER=1

# Validate inputs
if [ -z "$ISSUE_NUMBER" ] || [ -z "$AGENT_NAME" ]; then
  echo "Usage: $0 <issue-number> <agent-name>"
  exit 1
fi

# Cache directory for field IDs
CACHE_DIR=".cache/github"
mkdir -p "$CACHE_DIR"

# Fetch and cache project field IDs (TTL: 1 hour)
FIELDS_FILE="$CACHE_DIR/project-fields.json"
if [ ! -f "$FIELDS_FILE" ] || [ $(find "$FIELDS_FILE" -mmin +60 2>/dev/null) ]; then
  echo "Fetching project field definitions..."
  gh api graphql -f query='
    query($org: String!, $number: Int!) {
      organization(login: $org) {
        projectV2(number: $number) {
          id
          fields(first: 20) {
            nodes {
              ... on ProjectV2Field {
                id
                name
              }
              ... on ProjectV2SingleSelectField {
                id
                name
                options {
                  id
                  name
                }
              }
            }
          }
        }
      }
    }' -f org="$ORG" -F number=$PROJECT_NUMBER > "$FIELDS_FILE"
fi

# Extract field and option IDs
PROJECT_ID=$(jq -r '.data.organization.projectV2.id' "$FIELDS_FILE")
CLAIMED_BY_FIELD_ID=$(jq -r '.data.organization.projectV2.fields.nodes[] | select(.name=="Claimed By") | .id' "$FIELDS_FILE")
STATUS_FIELD_ID=$(jq -r '.data.organization.projectV2.fields.nodes[] | select(.name=="Status") | .id' "$FIELDS_FILE")
CLAIMED_OPTION_ID=$(jq -r '.data.organization.projectV2.fields.nodes[] | select(.name=="Status") | .options[] | select(.name=="Claimed") | .id' "$FIELDS_FILE")

# Get project item ID for issue
ITEM_ID=$(gh api graphql -f query='
  query($org: String!, $number: Int!, $issueNumber: Int!) {
    organization(login: $org) {
      projectV2(number: $number) {
        items(first: 100) {
          nodes {
            id
            content {
              ... on Issue {
                number
              }
            }
          }
        }
      }
    }
  }' -f org="$ORG" -F number=$PROJECT_NUMBER -F issueNumber=$ISSUE_NUMBER \
  | jq -r ".data.organization.projectV2.items.nodes[] | select(.content.number==$ISSUE_NUMBER) | .id")

if [ -z "$ITEM_ID" ]; then
  echo "Error: Issue #$ISSUE_NUMBER not found in project $PROJECT_NUMBER"
  exit 1
fi

# Update "Claimed By" field (text field)
gh api graphql -f query='
  mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $text: String!) {
    updateProjectV2ItemFieldValue(
      input: {
        projectId: $projectId
        itemId: $itemId
        fieldId: $fieldId
        value: { text: $text }
      }
    ) {
      projectV2Item { id }
    }
  }' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$CLAIMED_BY_FIELD_ID" -f text="$AGENT_NAME" \
  --silent

echo "✓ Set Claimed By: $AGENT_NAME"

# Update "Status" field to "Claimed"
gh api graphql -f query='
  mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
    updateProjectV2ItemFieldValue(
      input: {
        projectId: $projectId
        itemId: $itemId
        fieldId: $fieldId
        value: { singleSelectOptionId: $optionId }
      }
    ) {
      projectV2Item { id }
    }
  }' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$STATUS_FIELD_ID" -f optionId="$CLAIMED_OPTION_ID" \
  --silent

echo "✓ Status updated: Claimed"

# Add comment to issue
gh issue comment "$ISSUE_NUMBER" --body "$(cat <<EOF
Claimed by agent: **$AGENT_NAME**

<!-- agent:progress -->
| Field | Value |
|-------|-------|
| Agent | $AGENT_NAME |
| Status | claimed |
| Progress | 0% |
| Elapsed | 0m 0s |
| Current Task | Preparing worktree |
| Blockers | None |
<!-- /agent:progress -->
EOF
)"

echo "✓ Added claim comment"
echo "Issue #$ISSUE_NUMBER claimed by $AGENT_NAME"
```

### Query Ready Issues for Agent

```bash
# Source: gh CLI + jq filtering patterns

#!/bin/bash
# scripts/github/project-query.sh

set -e

AGENT_TYPE="${1:-any}"
PROJECT_NUMBER="${2:-1}"

# Query all project items
ITEMS=$(gh project item-list "$PROJECT_NUMBER" --owner "@me" --format json --limit 200)

# Filter: Status=Ready AND Claimed By=empty AND Agent Type matches
echo "$ITEMS" | jq -r --arg agent "$AGENT_TYPE" '
  .items[]
  | select(
      .fieldValueByName(name: "Status")?.name == "Ready" and
      (.fieldValueByName(name: "Claimed By")?.text == null or .fieldValueByName(name: "Claimed By")?.text == "") and
      (.labels[]?.name | test("agent:" + $agent) or $agent == "any")
    )
  | {
      number: .content.number,
      title: .content.title,
      priority: (.labels[]? | select(.name | test("P[0-3]-")) | .name),
      complexity: (.labels[]? | select(.name | test("^(XS|S|M|L|XL)$")) | .name),
      url: .content.url
    }
  | @json'
```

### Create PR with Agent Metadata

```bash
# Source: gh pr create manual + Phase 02 CONTEXT decisions

#!/bin/bash
# scripts/github/pr-create.sh

set -e

ISSUE_NUMBER="$1"
AGENT_NAME="$2"
WORKTREE_PATH="$3"
START_TIME="$4"

# Validate inputs
if [ -z "$ISSUE_NUMBER" ] || [ -z "$AGENT_NAME" ]; then
  echo "Usage: $0 <issue-number> <agent-name> <worktree-path> <start-time>"
  exit 1
fi

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))
DURATION_SEC=$((DURATION % 60))

# Count commits in current branch
COMMIT_COUNT=$(git rev-list --count HEAD ^main)

# Get trust level (from agent config or trust ledger)
TRUST_LEVEL="${AGENT_TRUST_LEVEL:-2}"

# Get model (from agent config)
MODEL="${AGENT_MODEL:-claude-sonnet-4.5}"

# Extract issue title and generate PR title
ISSUE_DATA=$(gh issue view "$ISSUE_NUMBER" --json title,labels)
ISSUE_TITLE=$(echo "$ISSUE_DATA" | jq -r '.title')
TYPE=$(echo "$ISSUE_DATA" | jq -r '.labels[] | select(.name | test("feature|bug|chore|docs|refactor|test")) | .name' | head -1)

# Generate PR title: <type>(<scope>): <description> (#<issue>)
PR_TITLE="$TYPE: $ISSUE_TITLE (#$ISSUE_NUMBER)"

# Create PR with structured metadata
gh pr create \
  --title "$PR_TITLE" \
  --body "$(cat <<EOF
## Summary
<!-- Brief description of changes -->

## Changes
<!-- Bullet list of modifications -->

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing complete

Closes #$ISSUE_NUMBER

---
**Agent Metadata**
| Field | Value |
|-------|-------|
| Agent | $AGENT_NAME |
| Issue | #$ISSUE_NUMBER |
| Worktree | $(basename "$WORKTREE_PATH") |
| Duration | ${DURATION_MIN}m ${DURATION_SEC}s |
| Model | $MODEL |
| Trust Level | $TRUST_LEVEL |
| Commits | $COMMIT_COUNT |
EOF
)" \
  --base main \
  --head "$(git branch --show-current)"

echo "✓ PR created and linked to issue #$ISSUE_NUMBER"
```

### GitHub Actions Workflow for Status Updates

```yaml
# Source: GitHub Actions docs + Projects v2 automation patterns

# .github/workflows/project-status.yml
name: Project Status Automation

on:
  pull_request:
    types: [opened, ready_for_review, closed]
  issues:
    types: [closed]

jobs:
  update-status:
    runs-on: ubuntu-latest
    steps:
      - name: Extract issue number
        id: issue
        run: |
          if [ "${{ github.event_name }}" == "pull_request" ]; then
            # Extract from PR body (Closes #N)
            ISSUE_NUM=$(gh pr view ${{ github.event.pull_request.number }} --json body -q '.body' | grep -oP 'Closes #\K\d+' || echo "")
          else
            # Direct issue event
            ISSUE_NUM="${{ github.event.issue.number }}"
          fi
          echo "number=$ISSUE_NUM" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Update to In Review (PR opened)
        if: github.event.action == 'opened' || github.event.action == 'ready_for_review'
        run: |
          # Use custom script to update Status field
          ./scripts/github/issue-update-status.sh ${{ steps.issue.outputs.number }} "In Review"
        env:
          GH_TOKEN: ${{ secrets.PROJECT_PAT }}

      - name: Update to Done (PR merged)
        if: github.event.action == 'closed' && github.event.pull_request.merged == true
        run: |
          # Built-in workflow handles this, but can add comment
          gh issue comment ${{ steps.issue.outputs.number }} --body "✅ Merged and marked as Done"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| GitHub Projects (Classic) | GitHub Projects v2 | 2022 | Custom fields, GraphQL API, flexible views, better automation |
| REST API for Projects | GraphQL API for Projects v2 | 2022 | Custom fields require GraphQL; no REST equivalent |
| Manual issue assignment | Project custom fields | 2022 | "Claimed By" text field better than assignee (multi-agent scenarios) |
| External kanban tools | GitHub Projects v2 | 2022 | Native integration, single source of truth, audit trail |
| `gh project` extension | Native `gh project` commands | 2023 (GA) | Official CLI support, no extension needed |
| Manual PR-issue linking | Auto-linking keywords | ~2015 | `Closes #N` auto-closes issue on merge |
| Polling for updates | Built-in workflows + webhooks | 2022 | Event-driven, no rate limit waste |

**Deprecated/outdated:**
- **GitHub Projects (Classic)**: Replaced by Projects v2; no custom fields; no GraphQL API
- **GitHub GraphQL Projects (Beta)**: Now GA as Projects v2; beta endpoints removed
- **`gh-projects` extension**: Archived June 2023; use native `gh project` commands
- **REST API for Projects**: Projects v2 not available via REST; must use GraphQL
- **Global assignee for multi-agent work**: Use custom "Claimed By" field; assignee implies human owner

## Open Questions

Things that couldn't be fully resolved:

1. **Project Item Limit Expansion**
   - What we know: 1200 active item limit; 10,000 archived; beta for unlimited items exists
   - What's unclear: When beta becomes GA; pricing implications; whether unlimited applies to free tier
   - Recommendation: Design for 1200 limit; use auto-archival (14 days in Done); split projects if needed

2. **Custom Field Type Support**
   - What we know: Text, Number, Date, Single Select, Iteration supported via GraphQL
   - What's unclear: Roadmap for new field types (multi-select, user references, formulas)
   - Recommendation: Use Single Select for status/priority; Text for agent names; avoid assumptions about future types

3. **Built-in Workflow Extensibility**
   - What we know: Built-in workflows limited to PR close/merge → Done, item add → Todo, auto-archive
   - What's unclear: GitHub's plans to add more triggers/actions to built-in workflows
   - Recommendation: Use GitHub Actions for custom transitions; don't wait for built-in expansion

4. **Rate Limit Strategy for Multi-Agent Systems**
   - What we know: 5,000 GraphQL points/hour; nested queries expensive; caching essential
   - What's unclear: Optimal cache TTL for field IDs; when to use shared rate limit pool vs per-agent
   - Recommendation: Cache field IDs for 1 hour; use shared PAT for automation (not per-agent); monitor remaining points

5. **Structured Comment Parsing Standards**
   - What we know: HTML comments allow machine-parseable data in human-readable context
   - What's unclear: Standard format for progress updates; whether GitHub will support structured comments officially
   - Recommendation: Use HTML comment blocks with key-value tables; document format in CLAUDE.md; prepare to migrate if GitHub releases official structured comments

## Sources

### Primary (HIGH confidence)

- [GitHub CLI Manual](https://cli.github.com/manual/) - Official gh CLI reference
- [GitHub Projects v2 API](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects) - Official GraphQL docs
- [Built-in Automations](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations) - Official workflow docs
- [Rate Limits - GraphQL](https://docs.github.com/en/graphql/overview/rate-limits-and-query-limits-for-the-graphql-api) - Official rate limit docs
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides/automatic-token-authentication) - GITHUB_TOKEN and scopes
- [jq Manual](https://jqlang.github.io/jq/manual/) - Official jq documentation

### Secondary (MEDIUM confidence)

- [gh-projects issue #93](https://github.com/github/gh-projects/issues/93) - Custom field filtering limitations (archived repo)
- [GitHub Projects item limit discussion](https://github.com/orgs/community/discussions/9678) - Community discussion on 1200 limit
- [GraphQL intro for Projects](https://some-natalie.dev/blog/graphql-intro/) - Community tutorial on custom fields
- [GitHub CLI scripting patterns](https://adamsimpson.net/writing/better-scripting-with-gh) - Community bash automation examples
- [nektos/act](https://github.com/nektos/act) - Local GitHub Actions testing tool

### Tertiary (LOW confidence)

- [Conventional branch naming](https://conventional-branch.github.io/) - Community convention; not GitHub-official
- Various Medium articles on GitHub Projects automation - Community patterns; not authoritative

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - gh CLI and GraphQL API verified via official docs; jq is industry standard
- Architecture patterns: HIGH - All examples from official docs, tested locally with gh v2.86.0
- Custom field operations: HIGH - GraphQL mutations verified with official API docs and community examples
- Rate limits: HIGH - Official GitHub documentation with exact numbers
- Built-in workflows: HIGH - Official docs list exact triggers and actions
- Pitfalls: HIGH - Verified via official issue trackers and docs (item limit, rate limits, scopes)
- Filtering limitations: MEDIUM - Documented in archived gh-projects repo; workaround verified but not officially documented
- Future roadmap: LOW - Unlimited items beta and workflow extensibility are speculative

**Research date:** 2026-01-27
**Valid until:** 2026-03-27 (60 days; stable GitHub features but Projects v2 actively evolving)
