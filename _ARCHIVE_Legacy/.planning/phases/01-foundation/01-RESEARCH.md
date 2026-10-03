# Phase 1: Foundation - Research

**Researched:** 2026-01-27
**Domain:** Git repository architecture, agent manifest design, worktree automation
**Confidence:** HIGH

## Summary

Phase 01 establishes the core infrastructure for multi-project orchestration through git submodules, agent manifest schemas, directory conventions, and automated worktree management. The research reveals well-established patterns for each component, though worktree automation for parallel AI agents represents an emerging domain with recent tooling innovations (Worktrunk, Jan 2026).

**Key findings:**
- Git submodules are mature but require disciplined workflows to avoid common pitfalls (detached HEAD, unpushed changes, stale references)
- Git worktrees excel for parallel development when paired with automation (naming conventions, lifecycle management, cleanup strategies)
- JSON Schema is the authoritative approach for YAML validation, with Ajv as the performance leader in JavaScript
- CLI directory structure follows XDG conventions with configuration precedence: flags > env vars > project > user > system

**Primary recommendation:** Use git's native submodule and worktree features with automation layers (shell scripts, hooks) rather than third-party abstractions. Build manifest validation using JSON Schema + Ajv + js-yaml for maximum portability and ecosystem alignment.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Git | 2.13+ | Version control, submodules, worktrees | Native support for multi-tree workflows; 2.13+ adds `--recurse-submodules` automation |
| js-yaml | 4.1.1 | YAML parsing | Most popular YAML library (23k+ dependents); full YAML 1.2 support |
| Ajv | 8.x | JSON Schema validation | Fastest validator (compiles schemas to JS); supports all JSON Schema drafts through 2020-12 |
| Node.js | 18+ LTS | Runtime | LTS support, native ES modules, stability for CLI tools |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| simple-git | Latest | Git operations from Node | Programmatic git commands (submodule add, worktree list) |
| commander | Latest | CLI argument parsing | Standard for Node.js CLI frameworks; used by major tools |
| chalk | Latest | Terminal colors | Conditional coloring (respects NO_COLOR, TTY detection) |
| ora | Latest | Progress spinners | Long-running operations (git clone --recursive) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| js-yaml | yaml (eemeli) | More complete YAML 1.2 implementation but less battle-tested |
| Ajv | jsonschema | Simpler API but 8-10x slower performance |
| Git native | Worktrunk CLI | Abstracts worktree UX but adds dependency; consider patterns, not tool |
| Simple-git | Bash + exec | More direct but loses cross-platform compatibility (Windows) |

**Installation:**
```bash
npm install js-yaml ajv simple-git commander chalk ora --save
npm install @types/js-yaml ajv-formats --save-dev
```

## Architecture Patterns

### Recommended Project Structure

```
manifest-automations/
├── .claude/
│   ├── agents/              # Agent manifests (YAML files)
│   ├── commands/            # Agency-wide commands
│   ├── skills/              # Agency-wide skills
│   └── hooks/               # Git hooks for trust enforcement (later phase)
├── .planning/
│   ├── phases/              # Phase planning docs
│   ├── config.json          # Planning configuration
│   └── trust-ledger.md      # Trust metrics (later phase)
├── projects/                # Git submodules (project-name/)
│   └── .gitkeep             # Preserve directory if empty
├── templates/
│   ├── agent-manifest/      # Agent YAML templates
│   ├── project-scaffold/    # New project structure
│   └── documentation/       # Doc templates
├── src/
│   ├── cli/                 # CLI entry point
│   ├── orchestrator/        # Agent dispatch logic (later phase)
│   ├── manifest/            # Manifest validation
│   ├── worktree/            # Worktree lifecycle management
│   └── submodule/           # Submodule operations
├── .gitmodules              # Submodule registry (git-managed)
├── package.json
├── CLAUDE.md                # Agency conventions
└── README.md
```

### Pattern 1: Sibling Worktree Naming

**What:** Worktrees live alongside main repo, not nested inside
**When to use:** All worktree creation (isolation, easy cleanup, prevents path confusion)
**Example:**
```bash
# Main repo
/path/to/manifest-automations/

# Worktrees (siblings)
/path/to/manifest-automations-feature-a/
/path/to/manifest-automations-bugfix-123/

# Pattern: {repo-name}-{branch-name}
```

**Why:** Quick visibility into active work via `ls ..`; prevents deletion issues; portable paths

**Source:** [Worktrunk CLI](https://github.com/max-sixty/worktrunk), [Git Worktree Best Practices](https://joshtune.com/posts/git-worktree-pros-cons/)

### Pattern 2: Outcome-Based Worktree Cleanup

**What:** Cleanup strategy based on PR outcome + time-based fallback
**When to use:** Post-merge, post-rejection, inactivity timeout
**Example:**
```javascript
// Pseudo-code for cleanup logic
function cleanupWorktree(worktree, outcome) {
  if (outcome === 'merged') {
    // PR merged → immediate cleanup
    git.worktree.remove(worktree)
    git.branch.delete(worktree.branch)
  } else if (outcome === 'closed') {
    // PR closed → archive or delete based on policy
    git.worktree.lock(worktree, 'archived-pr-closed')
  } else if (worktree.lastActivity > TIMEOUT_DAYS) {
    // Stale → prune administrative files
    git.worktree.prune({ expire: `${TIMEOUT_DAYS}.days.ago` })
  }
}
```

**Source:** Context decisions from Phase 01 CONTEXT.md, [Worktrunk lifecycle management](https://github.com/max-sixty/worktrunk)

### Pattern 3: Layered Configuration (XDG-style)

**What:** Configuration precedence with override layers
**When to use:** Agent manifests, CLI settings, project preferences
**Example:**
```javascript
// Config resolution order (highest to lowest precedence)
const config = {
  ...systemConfig,           // /etc/manifest-automations/config.json
  ...userConfig,             // ~/.config/manifest-automations/config.json
  ...projectConfig,          // ./.claude/config.json
  ...envVars,                // MANIFEST_* environment variables
  ...cliFlags                // --model=opus-4.5
}
```

**Source:** [CLI Design Guidelines](https://clig.dev/)

### Pattern 4: Git Submodule with Relative URLs

**What:** Use relative URLs in `.gitmodules` for portability
**When to use:** Submodules within same organization/hosting
**Example:**
```ini
# .gitmodules
[submodule "projects/customer-portal"]
	path = projects/customer-portal
	url = ../customer-portal.git  # Relative to parent repo URL
	branch = main
```

**Benefits:** Works across GitHub/GitLab/self-hosted; no URL rewriting when cloning forks

**Source:** [Git Submodules Official Docs](https://git-scm.com/book/en/v2/Git-Tools-Submodules)

### Pattern 5: Agent Manifest with Provider Adapters

**What:** Universal base schema + provider-specific extensions
**When to use:** Defining agents that work across Claude, Gemini, etc.
**Example:**
```yaml
# agent-manifest.yaml
name: code-reviewer
version: 1.0.0
description: Reviews code for style, security, and best practices

# Universal base (all providers)
tools:
  - read_file
  - write_file
  - run_bash

constraints:
  allow:
    - "src/**"
    - "tests/**"
  deny:
    - "**/.env"
    - "**/credentials.json"

# Provider-specific extensions
providers:
  claude:
    skills:
      - code-review
    toolSchemas:
      - mcp__linter__*
  gemini:
    functionDeclarations:
      - lint_code
      - analyze_security
```

**Source:** Phase 01 CONTEXT.md decisions on metadata layering

### Anti-Patterns to Avoid

- **Never modify submodule code in parent worktree**: Always `cd` into submodule, checkout branch, then commit
- **Never `git worktree remove` manually deleted directories**: Use `git worktree prune` to clean up metadata
- **Never assume detached HEAD in submodule is intentional**: Always `git checkout <branch>` before making changes
- **Never push parent before submodule**: Use `git push --recurse-submodules=on-demand` to enforce order
- **Never use absolute paths in `.gitmodules`**: Breaks portability across environments

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML validation | Custom parser + validator | JSON Schema + Ajv | JSON Schema is portable; Ajv compiles to optimized JS (8-10x faster than alternatives); ecosystem tooling (VSCode validation, auto-complete) |
| Git operations | Manual shell exec + parsing | simple-git library | Cross-platform (Windows CMD vs Bash); error handling; promise-based API; battle-tested on 10k+ projects |
| CLI argument parsing | Manual `process.argv` parsing | commander or yargs | Option validation, help generation, subcommands, type coercion, env var fallback |
| Terminal colors | ANSI code strings | chalk or picocolors | TTY detection, NO_COLOR respect, cross-platform (Windows terminal differences) |
| Worktree state tracking | Custom JSON store | Git native refs + `git worktree list --porcelain` | Git is source of truth; no state drift; porcelain output is script-friendly |

**Key insight:** Git's native features (submodules, worktrees, refs) are more reliable than external state management. Build automation *on top of* git primitives, not *around* them. Use JSON Schema for validation because it's the only truly portable, tooling-supported schema language.

## Common Pitfalls

### Pitfall 1: Unpushed Submodule Changes

**What goes wrong:** Parent repo references a submodule commit that only exists locally. Collaborators see "unable to checkout submodule" errors.

**Why it happens:** Git allows parent commit even if submodule commits aren't pushed. No automatic validation.

**How to avoid:**
```bash
# Option 1: Push check flag
git push --recurse-submodules=check  # Aborts if submodule commits unpushed

# Option 2: Auto-push (recommended)
git config push.recurseSubmodules on-demand
git push  # Automatically pushes submodule commits first
```

**Warning signs:**
- `git status` shows clean but submodules have commits
- CI fails with "reference is not a tree" errors
- Collaborators can't update submodules

**Source:** [Git Submodules Official Docs](https://git-scm.com/book/en/v2/Git-Tools-Submodules)

### Pitfall 2: Detached HEAD in Submodules

**What goes wrong:** `git submodule update` leaves submodule in detached HEAD state. Commits made in this state can be lost during next update.

**Why it happens:** Submodules track specific commits (SHA), not branches. Update command checks out that SHA.

**How to avoid:**
```bash
# Always checkout a branch before making changes
cd projects/submodule-name
git checkout main  # Or feature branch

# OR: Track branch automatically
git config -f .gitmodules submodule.projects/submodule-name.branch main
git submodule update --remote --merge  # Updates to tracked branch tip
```

**Warning signs:**
- `git branch` shows `(HEAD detached at abc1234)`
- Commits disappear after `git submodule update`
- `git log` shows unreachable commits

**Source:** [Git Submodules Common Mistakes](https://www.atlassian.com/git/tutorials/git-submodule)

### Pitfall 3: Worktree Branch Conflicts

**What goes wrong:** Same branch checked out in multiple worktrees. Changes in one worktree conflict with another, causing confusion.

**Why it happens:** Git allows checking out same branch in multiple worktrees with `-f` flag. No automatic conflict detection.

**How to avoid:**
```bash
# Don't use -f unless you understand the consequences
git worktree add ../repo-feature feature  # Errors if 'feature' already checked out
# Error: 'feature' is already checked out at '/path/to/other/worktree'

# Policy: One branch per worktree at a time
# Create new branches for parallel work
git worktree add -b feature-v2 ../repo-feature-v2 main
```

**Warning signs:**
- Unexpected merge conflicts when switching worktrees
- Changes "disappear" between worktrees
- Index lock errors

**Source:** [Git Worktree Gotchas](https://joshtune.com/posts/git-worktree-pros-cons/)

### Pitfall 4: Submodule URL Changes

**What goes wrong:** Submodule repository URL changes (rename, moved to different org). All clones break with "repository not found" errors.

**Why it happens:** `.gitmodules` stores URLs. Changes upstream aren't automatically propagated.

**How to avoid:**
```bash
# When submodule URL changes, sync and update
git config -f .gitmodules submodule.projects/submodule-name.url https://new-url.git
git submodule sync --recursive  # Updates .git/config from .gitmodules
git submodule update --init --recursive
git add .gitmodules
git commit -m "Update submodule URL"
```

**Warning signs:**
- `fatal: repository 'https://old-url.git' not found`
- Submodule updates hang or timeout
- Different team members report different clone behavior

**Source:** [Git Submodules Official Docs](https://git-scm.com/book/en/v2/Git-Tools-Submodules)

### Pitfall 5: Worktree Dependency Duplication

**What goes wrong:** Each worktree requires full `npm install` (or equivalent). Disk usage explodes; 10 worktrees = 10x `node_modules`.

**Why it happens:** Each worktree is independent working directory. Dependencies don't share by default.

**How to avoid:**
```bash
# Option 1: Use pnpm (content-addressable storage)
# Shared store reduces duplication by 60-80%
pnpm install  # In each worktree

# Option 2: Aggressive cleanup policy
# Remove worktree immediately after PR merged
git worktree remove ../repo-feature
git branch -d feature

# Option 3: Symbolic links (advanced)
# Share node_modules across worktrees (risky for conflicting versions)
ln -s ../../main-repo/node_modules ../worktree-feature/node_modules
```

**Warning signs:**
- Disk usage grows 10x faster than code
- `npm install` takes minutes in each worktree
- CI warnings about disk space

**Source:** [Parallel AI Development with Worktrees](https://sgryt.com/posts/git-worktree-parallel-ai-development/)

### Pitfall 6: JSON Schema Incompatibility with YAML Features

**What goes wrong:** YAML features like anchors (`&anchor`), aliases (`*alias`), or merge keys (`<<:`) fail validation even when YAML is valid.

**Why it happens:** JSON Schema validates the *resolved* JavaScript object, not YAML syntax. Advanced YAML features resolve before validation.

**How to avoid:**
```javascript
// This is actually fine - js-yaml resolves anchors before validation
const yaml = require('js-yaml')
const Ajv = require('ajv')

const yamlContent = `
base: &base
  name: common
  version: 1.0

agent1:
  <<: *base  # Merge key
  role: executor
`

const data = yaml.load(yamlContent)  // Anchors/aliases resolved
const ajv = new Ajv()
const valid = ajv.validate(schema, data)  // Validates resolved object
```

**Real gotcha:** YAML 1.1 vs 1.2 differences (e.g., `yes`/`no` as booleans in 1.1 but strings in 1.2). Use js-yaml's `CORE_SCHEMA` for 1.2 strict mode.

**Warning signs:**
- Validation passes in YAML editor but fails in code
- Boolean values become strings (`yes` → `"yes"`)
- Octals parse incorrectly (`0123` → `83` in 1.1, `"0123"` in 1.2)

**Source:** [JSON Schema for YAML](https://json-schema-everywhere.github.io/yaml)

## Code Examples

Verified patterns from official sources:

### Submodule: Add and Configure

```bash
# Source: https://git-scm.com/book/en/v2/Git-Tools-Submodules

# Add submodule with relative URL
git submodule add ../customer-portal.git projects/customer-portal

# Configure branch tracking
git config -f .gitmodules submodule.projects/customer-portal.branch main

# Set default behaviors (in parent repo)
git config submodule.recurse true  # Auto-recurse for most commands
git config push.recurseSubmodules on-demand  # Auto-push submodules
git config status.submodulesummary 1  # Show submodule changes in status
```

### Worktree: Create and Cleanup

```bash
# Source: https://git-scm.com/docs/git-worktree

# Create worktree with new branch (sibling pattern)
git worktree add -b feature-auth ../manifest-automations-feature-auth

# List all worktrees (machine-readable)
git worktree list --porcelain
# Output:
# worktree /path/to/manifest-automations
# HEAD abc1234...
# branch refs/heads/main
#
# worktree /path/to/manifest-automations-feature-auth
# HEAD def5678...
# branch refs/heads/feature-auth

# Remove worktree (clean only)
git worktree remove ../manifest-automations-feature-auth

# Prune stale metadata (after manual deletion)
git worktree prune --verbose
```

### YAML Validation with JSON Schema

```javascript
// Source: https://ajv.js.org/guide/getting-started.html
// Source: https://www.npmjs.com/package/js-yaml

const fs = require('fs')
const yaml = require('js-yaml')
const Ajv = require('ajv')
const addFormats = require('ajv-formats')

// Define JSON Schema for agent manifest
const agentSchema = {
  $schema: 'http://json-schema.org/draft-07/schema#',
  type: 'object',
  required: ['name', 'version', 'tools'],
  properties: {
    name: {
      type: 'string',
      pattern: '^[a-z0-9-]+$',
      description: 'Agent identifier (kebab-case)'
    },
    version: {
      type: 'string',
      pattern: '^\\d+\\.\\d+\\.\\d+$',
      description: 'Semantic version'
    },
    description: { type: 'string' },
    tools: {
      type: 'array',
      items: { type: 'string' },
      minItems: 1
    },
    constraints: {
      type: 'object',
      properties: {
        allow: {
          type: 'array',
          items: { type: 'string' }
        },
        deny: {
          type: 'array',
          items: { type: 'string' }
        }
      }
    },
    providers: {
      type: 'object',
      additionalProperties: { type: 'object' }
    }
  }
}

// Validate YAML file
function validateAgentManifest(filePath) {
  // Parse YAML to JavaScript object
  const fileContents = fs.readFileSync(filePath, 'utf8')
  const data = yaml.load(fileContents, { schema: yaml.CORE_SCHEMA }) // YAML 1.2

  // Validate against schema
  const ajv = new Ajv({ allErrors: true })
  addFormats(ajv) // Add format validators (email, url, etc.)

  const validate = ajv.compile(agentSchema)
  const valid = validate(data)

  if (!valid) {
    console.error('Validation errors:')
    validate.errors.forEach(err => {
      console.error(`  ${err.instancePath}: ${err.message}`)
    })
    return false
  }

  return true
}

// Usage
const isValid = validateAgentManifest('.claude/agents/code-reviewer.yaml')
```

### Worktree Lifecycle Automation

```javascript
// Source: https://github.com/max-sixty/worktrunk (pattern inspiration)

const simpleGit = require('simple-git')
const git = simpleGit()
const path = require('path')

async function createWorktree(branchName, baseBranch = 'main') {
  const repoName = path.basename(process.cwd())
  const worktreePath = path.resolve('..', `${repoName}-${branchName}`)

  try {
    // Create worktree with new branch
    await git.raw([
      'worktree', 'add',
      '-b', branchName,
      worktreePath,
      baseBranch
    ])

    console.log(`✓ Worktree created: ${worktreePath}`)
    return worktreePath
  } catch (error) {
    if (error.message.includes('already checked out')) {
      throw new Error(`Branch '${branchName}' is already checked out in another worktree`)
    }
    throw error
  }
}

async function removeWorktree(branchName) {
  const repoName = path.basename(process.cwd())
  const worktreePath = path.resolve('..', `${repoName}-${branchName}`)

  try {
    // Remove worktree
    await git.raw(['worktree', 'remove', worktreePath])

    // Delete branch
    await git.deleteLocalBranch(branchName)

    console.log(`✓ Worktree and branch removed: ${branchName}`)
  } catch (error) {
    if (error.message.includes('contains modified or untracked files')) {
      console.warn(`⚠ Worktree has uncommitted changes. Use -f to force removal.`)
      throw error
    }
    throw error
  }
}

async function listWorktrees() {
  const output = await git.raw(['worktree', 'list', '--porcelain'])

  // Parse porcelain output
  const worktrees = []
  const lines = output.split('\n')
  let current = {}

  for (const line of lines) {
    if (line.startsWith('worktree ')) {
      if (current.worktree) worktrees.push(current)
      current = { worktree: line.substring(9) }
    } else if (line.startsWith('HEAD ')) {
      current.head = line.substring(5)
    } else if (line.startsWith('branch ')) {
      current.branch = line.substring(7).replace('refs/heads/', '')
    } else if (line.startsWith('detached')) {
      current.detached = true
    }
  }
  if (current.worktree) worktrees.push(current)

  return worktrees
}

// Usage
;(async () => {
  await createWorktree('feature-auth', 'main')
  const worktrees = await listWorktrees()
  console.log('Active worktrees:', worktrees)
  await removeWorktree('feature-auth')
})()
```

### Configuration Precedence Pattern

```javascript
// Source: https://clig.dev/

const fs = require('fs')
const path = require('path')
const os = require('os')

function loadConfig() {
  const defaults = {
    model: 'claude-sonnet-4.5',
    parallelization: true,
    commit_docs: true
  }

  // Layer 1: System-wide config
  const systemConfig = loadJsonIfExists('/etc/manifest-automations/config.json')

  // Layer 2: User config (XDG Base Directory)
  const xdgConfigHome = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config')
  const userConfig = loadJsonIfExists(path.join(xdgConfigHome, 'manifest-automations', 'config.json'))

  // Layer 3: Project config
  const projectConfig = loadJsonIfExists('.planning/config.json')

  // Layer 4: Environment variables (prefix MANIFEST_)
  const envConfig = {}
  for (const [key, value] of Object.entries(process.env)) {
    if (key.startsWith('MANIFEST_')) {
      const configKey = key.substring(9).toLowerCase()
      envConfig[configKey] = parseEnvValue(value)
    }
  }

  // Layer 5: CLI flags (handled by commander, highest precedence)

  // Merge with precedence (later overrides earlier)
  return {
    ...defaults,
    ...systemConfig,
    ...userConfig,
    ...projectConfig,
    ...envConfig
  }
}

function loadJsonIfExists(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'))
  } catch {
    return {}
  }
}

function parseEnvValue(value) {
  if (value === 'true') return true
  if (value === 'false') return false
  if (/^\d+$/.test(value)) return parseInt(value, 10)
  return value
}

// Usage
const config = loadConfig()
console.log('Resolved config:', config)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `git submodule update` manual | `git config submodule.recurse true` | Git 2.14 (2017) | Automatic recursion for checkout, pull, push; reduces mental overhead |
| Separate `git submodule` commands | `git clone --recurse-submodules` | Git 2.13 (2016) | Single command initialization; better onboarding UX |
| Manual worktree cleanup | `git worktree prune` + `gc.worktreePruneExpire` | Git 2.17 (2018) | Automatic stale worktree cleanup via garbage collection |
| Kwalify/Rx for YAML validation | JSON Schema + Ajv | ~2020 | Portable across languages; ecosystem tooling (VSCode, Spectral); 8-10x faster |
| npm global installs for CLIs | npx + package bins | npm 5.2+ (2017) | No global pollution; version pinning; easier CI |
| Worktrees for hotfixes only | Worktrees for parallel AI agents | 2025-2026 | Orchestration use case; tools like Worktrunk (Jan 2026) emerging |

**Deprecated/outdated:**
- **Kwalify**: Ruby/Python only; minimal tooling; use JSON Schema instead
- **Rx Schema**: No recent development; limited adoption; use JSON Schema
- **Git submodule foreach loops**: Use `git config submodule.recurse true` for automatic recursion
- **Absolute URLs in .gitmodules**: Breaks portability; use relative URLs (e.g., `../repo.git`)
- **Manual `process.argv` parsing**: Use commander/yargs for validation, help generation, type coercion

## Open Questions

Things that couldn't be fully resolved:

1. **Submodule + Worktree Interaction**
   - What we know: Git docs warn "multiple checkouts of superproject not recommended" when using submodules
   - What's unclear: Specific failure modes; whether this affects parent repo worktrees with submodules OR submodule worktrees
   - Recommendation: Test early in Phase 01 implementation. Likely safe for parent worktrees; avoid creating worktrees *within* submodules.

2. **Worktree Cleanup Timeout Duration**
   - What we know: Cleanup should be outcome-based (merged/closed) + time-based fallback (inactivity)
   - What's unclear: Optimal timeout duration for AI agent workflows (3 days? 7 days? 30 days?)
   - Recommendation: Start with 7 days; make configurable; monitor actual usage patterns to tune.

3. **Agent Manifest Versioning Strategy**
   - What we know: Need semantic versioning for manifests; changes to schema should be backward compatible
   - What's unclear: How to handle breaking changes to manifest schema; migration strategy for existing agents
   - Recommendation: Follow JSON Schema's `$schema` versioning pattern. Use `$schema: "https://manifest-automations.dev/schema/v1.0.0"` with major version bumps for breaking changes.

4. **Worktree-Specific Configuration Sharing**
   - What we know: Git 2.29+ supports `extensions.worktreeConfig` for per-worktree settings
   - What's unclear: Which settings should be worktree-specific vs shared (e.g., core.sparseCheckout, hooks)
   - Recommendation: Default to shared config; only use worktree-specific for settings that vary by task (e.g., different dev server ports, debug flags).

## Sources

### Primary (HIGH confidence)

- [Git Submodules Official Docs](https://git-scm.com/book/en/v2/Git-Tools-Submodules) - Git Project
- [Git Worktree Official Docs](https://git-scm.com/docs/git-worktree) - Git Project
- [Ajv JSON Schema Validator](https://ajv.js.org/) - Official Ajv documentation
- [js-yaml npm package](https://www.npmjs.com/package/js-yaml) - Version 4.1.1, 23k+ dependents
- [CLI Design Guidelines](https://clig.dev/) - Community-maintained CLI best practices
- [JSON Schema for YAML](https://json-schema-everywhere.github.io/yaml) - JSON Schema community documentation

### Secondary (MEDIUM confidence)

- [Worktrunk CLI](https://github.com/max-sixty/worktrunk) - Released Jan 2026; worktree management patterns
- [Git Submodules Best Practices](https://blog.pixelfreestudio.com/best-practices-for-using-git-submodules/) - Verified against official docs
- [Git Worktree Gotchas](https://joshtune.com/posts/git-worktree-pros-cons/) - Community experience; cross-referenced with official docs
- [Parallel AI Development with Worktrees](https://medium.com/@dtunai/mastering-git-worktrees-with-claude-code-for-parallel-development-workflow-41dc91e645fe) - AI-specific use case
- [Monorepo Directory Structure](https://medium.com/@julakadaredrishi/monorepos-a-comprehensive-guide-with-examples-63202cfab711) - Domain organization patterns

### Tertiary (LOW confidence)

- [Multi-Agent Orchestration Patterns](https://medium.com/@MNIVKA/building-an-intelligent-multi-agent-system-with-node-js-ai-orchestration-a1cc2835230a) - Architecture concepts; not specific to our use case
- [Agentic Orchestration Frameworks 2026](https://research.aimultiple.com/agentic-orchestration/) - Market overview; high-level patterns only

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries verified via npm, official docs, adoption metrics
- Architecture: HIGH - Git patterns from official docs; CLI conventions from clig.dev (industry standard)
- Pitfalls: HIGH - Cross-referenced official docs with community experience; tested patterns
- YAML validation: HIGH - JSON Schema approach verified by multiple authoritative sources (json-schema-everywhere, Ajv docs)
- Worktree automation: MEDIUM - Emerging domain (Worktrunk Jan 2026); patterns extrapolated from tool design but not battle-tested at scale
- Agent manifest schema: MEDIUM - Design decisions from Phase 01 CONTEXT; pattern exists but no standard schema yet

**Research date:** 2026-01-27
**Valid until:** 2026-02-27 (30 days; stable domain with slow-moving standards)
