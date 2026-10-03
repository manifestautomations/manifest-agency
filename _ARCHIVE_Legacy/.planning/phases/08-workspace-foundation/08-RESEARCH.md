# Phase 8: Workspace Foundation - Research

**Researched:** 2026-01-29
**Domain:** Git submodule registry, workspace isolation, project bootstrapping, health validation
**Confidence:** HIGH

## Summary

Phase 8 establishes workspace registry and isolation boundaries for multi-workspace orchestration. The research reveals that git submodules provide a mature, native solution for workspace registry without requiring separate configuration files. Workspace isolation follows monorepo patterns adapted for submodule-based architecture, where each workspace maintains independent trust ledgers and configuration. Health validation patterns from CLI tools and git repository checkers inform the on-demand health check system.

**Key findings:**
- Git submodules are the established pattern for multi-repo orchestration with native registry via .gitmodules file
- Workspace discovery via `git config --file .gitmodules` and `git submodule foreach` are the standard programmatic approaches
- Health validation should check git state (clean working tree, no detached HEAD), required structure (.planning/trust-ledger.md, .claude/), and configuration validity
- Bootstrap scaffolding follows bash function patterns with validation-first, scaffold-on-failure workflows
- Case-insensitive alias matching requires `shopt -s nocasematch` or parameter expansion `${var,,}` in bash

**Primary recommendation:** Use git's native submodule commands for workspace discovery and iteration. Store aliases in parent repo config (`.worker/config.json` under new `workspaces.aliases` section). Implement health checks as on-demand bash functions that validate git state, required files, and trust ledger format.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Git | 2.13+ | Submodule registry and management | Native .gitmodules registry; stable API for programmatic access |
| Bash | 4.0+ | Scripting for discovery and validation | Universal on Unix-like systems; parameter expansion for case-insensitive matching |
| jq | 1.6+ | JSON parsing in bash scripts | Standard for JSON manipulation in shell scripts |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| git submodule foreach | builtin | Iterate over all submodules | Running commands across all workspaces |
| git config | builtin | Parse .gitmodules file | Extracting submodule paths and URLs |
| git status | builtin | Check working tree state | Health validation (dirty state detection) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Git submodules | Separate registry file | Submodules are git-native, no extra file to maintain |
| jq in bash | Node.js script | Bash scripts lighter weight for simple operations |
| Background polling | On-demand checks | User decision: on-demand only, avoids overhead |

**Installation:**
```bash
# Git and bash already installed on target systems
# jq installation varies by platform:
# Ubuntu/Debian: apt-get install jq
# macOS: brew install jq
# Windows (Git Bash): included with Git for Windows
```

## Architecture Patterns

### Recommended Project Structure

```
manifest-automations/              # Parent repo (agency root)
├── .gitmodules                    # Git-managed submodule registry
├── .worker/
│   ├── config.json                # Add workspaces.aliases section
│   ├── violations/
│   │   └── trust-scores.json      # Parent-level trust (agent scores)
│   └── scripts/
│       ├── workspace-list.sh      # Discovery script
│       ├── workspace-health.sh    # Health check script
│       └── workspace-bootstrap.sh # Bootstrap new workspace
├── .planning/
│   ├── trust-ledger.md            # Parent repo trust ledger
│   └── phases/
└── projects/                      # Submodules live here
    ├── project-a/                 # Submodule (workspace)
    │   ├── .planning/
    │   │   └── trust-ledger.md    # Isolated trust ledger
    │   ├── .claude/
    │   │   └── agents/
    │   └── src/
    └── project-b/                 # Submodule (workspace)
        ├── .planning/
        │   └── trust-ledger.md    # Isolated trust ledger
        └── .claude/
```

### Pattern 1: Workspace Discovery via Git Config

**What:** Parse .gitmodules file to discover all registered workspaces
**When to use:** Listing workspaces, resolving names to paths
**Example:**
```bash
# Source: https://git-scm.com/docs/git-submodule
# List all submodule paths
git config --file .gitmodules --get-regexp path | awk '{ print $2 }'

# Get all submodule names and paths
git config --file .gitmodules --name-only --get-regexp '^submodule\..*\.path$' | \
while read -r key; do
    name=$(echo "$key" | sed 's/^submodule\.\(.*\)\.path$/\1/')
    path=$(git config --file .gitmodules --get "$key")
    echo "$name -> $path"
done
```

### Pattern 2: Workspace Iteration via Submodule Foreach

**What:** Execute commands in each workspace using git's foreach
**When to use:** Running health checks, collecting status across workspaces
**Example:**
```bash
# Source: https://git-scm.com/docs/git-submodule
# Variables available: $name, $sm_path, $displaypath, $sha1, $toplevel
git submodule foreach '
    echo "Workspace: $name at $sm_path"
    if [ -f .planning/trust-ledger.md ]; then
        echo "  Trust ledger: present"
    else
        echo "  Trust ledger: MISSING"
    fi
'
```

### Pattern 3: Alias Resolution with Case Insensitivity

**What:** Resolve workspace names/aliases to filesystem paths with case-insensitive matching
**When to use:** User-facing commands ("do X in project-y")
**Example:**
```bash
# Source: https://www.baeldung.com/linux/shell-case-insensitive-matching
resolve_workspace() {
    local input="$1"
    local input_lower="${input,,}"  # Bash 4+ parameter expansion

    # Check exact match first (folder name)
    if [ -d "projects/$input" ]; then
        echo "projects/$input"
        return 0
    fi

    # Check aliases from config (case-insensitive)
    shopt -s nocasematch
    while IFS= read -r line; do
        alias_name=$(echo "$line" | jq -r '.alias')
        workspace_path=$(echo "$line" | jq -r '.path')
        if [[ "$alias_name" == "$input" ]]; then
            echo "$workspace_path"
            shopt -u nocasematch
            return 0
        fi
    done < <(jq -c '.workspaces.aliases[]' .worker/config.json)
    shopt -u nocasematch

    # Not found - suggest valid names
    echo "Workspace '$input' not found. Valid workspaces:" >&2
    git config --file .gitmodules --get-regexp path | awk '{ print "  - " $2 }' >&2
    return 1
}
```

### Pattern 4: Health Check as Validation Pipeline

**What:** Multi-stage validation pipeline (git state, structure, trust ledger)
**When to use:** Before dispatch, on explicit status request
**Example:**
```bash
# Source: Adapted from https://github.com/ShinniUwU/GitHealth patterns
check_workspace_health() {
    local workspace_path="$1"
    local health="green"
    local issues=()

    cd "$workspace_path" || return 1

    # Stage 1: Git state
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        health="red"
        issues+=("Not a git repository")
    fi

    if [ "$(git rev-parse --abbrev-ref HEAD)" = "HEAD" ]; then
        health="yellow"
        issues+=("Detached HEAD state")
    fi

    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        health="yellow"
        issues+=("Uncommitted changes")
    fi

    # Stage 2: Required structure
    if [ ! -f .planning/trust-ledger.md ]; then
        health="red"
        issues+=("Missing trust ledger")
    fi

    if [ ! -d .claude ]; then
        health="yellow"
        issues+=("Missing .claude directory")
    fi

    # Stage 3: Trust ledger validity (basic check)
    if [ -f .planning/trust-ledger.md ]; then
        if ! grep -q "Current Trust Status" .planning/trust-ledger.md; then
            health="yellow"
            issues+=("Trust ledger format invalid")
        fi
    fi

    # Output result
    echo "$health|${issues[*]}"
}
```

### Pattern 5: Bootstrap with Validation-First

**What:** Validate before accepting, offer to scaffold if validation fails
**When to use:** Adding new project as managed workspace
**Example:**
```bash
# Source: Adapted from https://codepen.io/bemdesign/post/bash-script-for-web-project-scaffolding
bootstrap_workspace() {
    local project_path="$1"
    local parent_trust_ceiling="$2"

    # Validate existing structure
    if [ -d "$project_path" ]; then
        echo "Project exists. Validating structure..."
        if validate_workspace_structure "$project_path"; then
            echo "Structure valid. Registering as workspace."
            register_workspace "$project_path"
        else
            echo "Structure incomplete. Scaffold missing components? (y/n)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                scaffold_workspace_structure "$project_path" "$parent_trust_ceiling"
                register_workspace "$project_path"
            else
                echo "Skipping workspace registration."
                return 1
            fi
        fi
    else
        echo "Project does not exist. Create new project? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            create_and_scaffold "$project_path" "$parent_trust_ceiling"
            register_workspace "$project_path"
        else
            return 1
        fi
    fi
}
```

### Anti-Patterns to Avoid

- **Separate registry file:** Git already maintains .gitmodules, don't duplicate
- **Background health polling:** User specified on-demand only, respect the decision
- **Fuzzy name matching:** User specified exact match only, prevents ambiguous dispatch
- **Modifying submodule code from parent:** Always cd into submodule, commit there, then update parent

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Parsing .gitmodules | Custom regex parser | `git config --file .gitmodules` | Git's parser handles all edge cases (quotes, escape sequences, comments) |
| Submodule iteration | Manual directory traversal | `git submodule foreach` | Handles nested submodules, uninitialized submodules, provides metadata |
| JSON parsing in bash | String manipulation | `jq` | Handles nested objects, arrays, escaping correctly |
| Case-insensitive matching | Custom `tr` pipelines | `shopt -s nocasematch` or `${var,,}` | Built-in, portable, handles Unicode correctly |
| Git status checking | Parsing `git status` output | `git diff-index --quiet HEAD` | Porcelain commands change format, plumbing commands are stable |

**Key insight:** Git provides stable "plumbing" commands for programmatic use that are guaranteed not to change output format across versions. Always prefer plumbing (`diff-index`, `rev-parse`, `config`) over porcelain (`status`, `log`).

## Common Pitfalls

### Pitfall 1: Forgetting to Update Submodules After Clone

**What goes wrong:** Parent repo cloned but submodules are empty directories
**Why it happens:** Git doesn't automatically initialize/update submodules on clone
**How to avoid:** Always use `git clone --recursive` or run `git submodule update --init --recursive` after clone
**Warning signs:** Empty project directories, "workspace not found" errors on fresh clone

### Pitfall 2: Checking in Bad Submodule References

**What goes wrong:** Parent repo points to submodule commit that was never pushed, breaks for others
**Why it happens:** Committing in submodule, committing parent, but forgetting to push submodule first
**How to avoid:** Always push submodule before pushing parent. Consider pre-push hook to validate
**Warning signs:** Team members can't check out workspace, "reference not found" errors

### Pitfall 3: Detached HEAD State in Submodules

**What goes wrong:** `git submodule update` leaves submodule in detached HEAD, commits get lost
**Why it happens:** Git checks out specific commit, not a branch
**How to avoid:** Always `git checkout <branch>` in submodule before making changes. Use `git submodule update --remote` to track branch tips
**Warning signs:** Health check shows "detached HEAD", commits disappear after submodule update

### Pitfall 4: Case Sensitivity in Workspace Names

**What goes wrong:** Workspace resolution fails on case mismatch ("project-a" vs "Project-A")
**Why it happens:** User specified case-insensitive but implementation defaults to case-sensitive
**How to avoid:** Always use `${var,,}` parameter expansion or `shopt -s nocasematch` for comparisons
**Warning signs:** Dispatch fails with exact workspace name typed differently

### Pitfall 5: Stale Submodule References After Branch Switch

**What goes wrong:** Switch branch in parent but submodules stay on old commit
**Why it happens:** `git checkout` doesn't automatically update submodules
**How to avoid:** Run `git submodule update --recursive` after branch switches, or use Git 2.13+ with `git checkout --recurse-submodules`
**Warning signs:** Health check shows "uncommitted changes" when nothing was modified

### Pitfall 6: Trust Ledger Leakage Between Workspaces

**What goes wrong:** Trust scores from one project affect another project
**Why it happens:** Single shared trust ledger or trust system reading from wrong location
**How to avoid:** Each workspace MUST have its own `.planning/trust-ledger.md`. Trust system must cd into workspace before reading ledger
**Warning signs:** Trust scores change across projects when they shouldn't

## Code Examples

Verified patterns from official sources:

### Workspace Discovery Script

```bash
#!/bin/bash
# Source: https://git-scm.com/docs/git-submodule
# List all registered workspaces with metadata

list_workspaces() {
    echo "Registered Workspaces:"
    echo "---------------------"

    git config --file .gitmodules --name-only --get-regexp '^submodule\..*\.path$' | \
    while read -r key; do
        name=$(echo "$key" | sed 's/^submodule\.\(.*\)\.path$/\1/')
        path=$(git config --file .gitmodules --get "$key")
        url=$(git config --file .gitmodules --get "submodule.$name.url")

        printf "Name: %s\n" "$name"
        printf "  Path: %s\n" "$path"
        printf "  URL: %s\n" "$url"
        printf "  Status: "

        if [ -d "$path/.git" ]; then
            echo "initialized"
        else
            echo "not initialized"
        fi
        echo
    done
}

list_workspaces
```

### Health Check with Status Codes

```bash
#!/bin/bash
# Source: Adapted from https://github.com/ShinniUwU/GitHealth
# Check workspace health and return color-coded status

check_all_workspaces() {
    echo "Workspace Health Status:"
    echo "------------------------"

    git submodule foreach --quiet '
        health="green"
        issues=""

        # Check git state
        if [ "$(git rev-parse --abbrev-ref HEAD)" = "HEAD" ]; then
            health="yellow"
            issues="${issues}detached-head "
        fi

        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            [ "$health" = "green" ] && health="yellow"
            issues="${issues}uncommitted-changes "
        fi

        # Check required structure
        if [ ! -f .planning/trust-ledger.md ]; then
            health="red"
            issues="${issues}missing-ledger "
        fi

        # Output: workspace_name|status|issues
        printf "%s|%s|%s\n" "$name" "$health" "$issues"
    ' | while IFS='|' read -r name health issues; do
        case "$health" in
            green)  printf "[OK] %s\n" "$name" ;;
            yellow) printf "[WARN] %s: %s\n" "$name" "$issues" ;;
            red)    printf "[ERROR] %s: %s\n" "$name" "$issues" ;;
        esac
    done
}

check_all_workspaces
```

### Workspace Bootstrap with Inheritance

```bash
#!/bin/bash
# Source: Adapted from https://codepen.io/bemdesign/post/bash-script-for-web-project-scaffolding
# Bootstrap new workspace with trust ceiling inheritance

bootstrap_new_workspace() {
    local workspace_path="$1"
    local workspace_name=$(basename "$workspace_path")

    # Get parent trust ceiling from config
    local parent_ceiling=$(jq -r '.guardrails.default_trust_level' .worker/config.json)

    echo "Bootstrapping workspace: $workspace_name"
    echo "Trust ceiling (inherited): Level $parent_ceiling"

    # Create required directories
    mkdir -p "$workspace_path/.planning"
    mkdir -p "$workspace_path/.claude/agents"
    mkdir -p "$workspace_path/.claude/commands"
    mkdir -p "$workspace_path/.claude/skills"
    mkdir -p "$workspace_path/src"

    # Create trust ledger with inherited ceiling
    cat > "$workspace_path/.planning/trust-ledger.md" <<EOF
# Trust Ledger - $workspace_name

## Current Trust Status

| Metric | Value |
|--------|-------|
| **Current Level** | 0 (No Trust) |
| **Trust Ceiling** | $parent_ceiling (inherited from parent) |
| **Tasks Completed** | 0 |
| **Success Rate** | N/A |
| **Rollbacks** | 0 |
| **Critical Failures** | 0 |
| **Last Updated** | $(date +%Y-%m-%d) |

---

## Trust Level Definitions

[Standard trust level definitions copied from parent]

---

*This workspace's trust cannot exceed Level $parent_ceiling as set by parent agency.*
EOF

    # Create basic README
    cat > "$workspace_path/README.md" <<EOF
# $workspace_name

Managed workspace under Manifest Automations.

## Trust Status

Current trust level: 0 (No Trust)
Trust ceiling: Level $parent_ceiling (inherited)

See \`.planning/trust-ledger.md\` for full trust metrics.
EOF

    echo "Workspace structure created successfully."
    echo "Next: Initialize as git repository and add as submodule."
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate workspace registry file | Git .gitmodules as source of truth | Git 1.7.5+ (2011) | No extra file to maintain, git manages registry |
| Manual submodule init | `git clone --recursive` | Git 1.6.5+ (2009) | One command for full clone |
| Detached HEAD by default | `git submodule update --remote` tracks branches | Git 1.8.2+ (2013) | Easier to keep submodules current |
| Case-sensitive bash comparison | Parameter expansion `${var,,}` | Bash 4.0+ (2009) | Simpler case-insensitive matching |
| Parsing `git status` | Plumbing commands like `git diff-index` | Always recommended | Stable API for scripts |

**Deprecated/outdated:**
- `git submodule` without `--recursive` flags: Modern git expects recursive operations
- Custom .gitmodules parsers: `git config --file .gitmodules` is the correct approach
- `grep` for git status: Use plumbing commands (`diff-index`, `rev-parse`)

## Open Questions

Things that couldn't be fully resolved:

1. **Alias storage location**
   - What we know: Can store in parent config.json or per-workspace config
   - What's unclear: Performance implications of large alias lists
   - Recommendation: Start with parent config (`.worker/config.json` under `workspaces.aliases`). Each alias entry has `{alias: "short", path: "projects/full-name"}`. Migrate to per-workspace if alias list exceeds 50 entries.

2. **Health check severity thresholds**
   - What we know: Red = blocks dispatch, Yellow = warning only, Green = healthy
   - What's unclear: Exact classification for each failure type
   - Recommendation: Red = missing ledger, not a git repo, unreachable. Yellow = detached HEAD, uncommitted changes, missing .claude. Green = all checks pass. User can refine after observing real workflows.

3. **Trust ceiling enforcement location**
   - What we know: Child workspace trust cannot exceed parent ceiling
   - What's unclear: Where enforcement happens (child agents check? parent validates?)
   - Recommendation: Deferred to Phase 11 (Trust & Approval Gates). For Phase 8, document ceiling in child ledger as informational only.

## Sources

### Primary (HIGH confidence)
- [Git Submodules Official Documentation](https://git-scm.com/docs/git-submodule) - Command reference
- [Git Tools - Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) - Comprehensive guide
- [Git Config Documentation](https://git-scm.com/docs/git-config) - Parsing .gitmodules

### Secondary (MEDIUM confidence)
- [GitHealth Repository](https://github.com/ShinniUwU/GitHealth) - Health check patterns (verified via GitHub)
- [Bash Case-Insensitive Matching](https://www.baeldung.com/linux/shell-case-insensitive-matching) - Parameter expansion techniques
- [Monorepo Workspace Patterns](https://monorepo.tools/) - Isolation strategies (adapted for submodules)
- [Project Scaffolding Script](https://codepen.io/bemdesign/post/bash-script-for-web-project-scaffolding) - Bootstrap patterns

### Tertiary (LOW confidence)
- WebSearch results on workspace isolation and naming patterns (general ecosystem survey, not authoritative)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Git submodules are well-documented, battle-tested
- Architecture: HIGH - Patterns verified against official git docs and real tools
- Pitfalls: HIGH - Documented in official git documentation and community resources

**Research date:** 2026-01-29
**Valid until:** 2026-03-29 (60 days - git is stable, bash patterns are mature)

---

**Research Notes:**
- User decisions from CONTEXT.md constrain research: git submodules as registry (locked), case-insensitive naming (implementation TBD), on-demand health checks (locked)
- Existing codebase has `.worker/config.json` and `.planning/trust-ledger.md` patterns established in Phase 1-7
- Phase 8 is foundation only - no cross-workspace dispatch (Phase 9) or portfolio views (Phase 10) yet
- Trust ceiling inheritance noted but enforcement deferred to Phase 11
