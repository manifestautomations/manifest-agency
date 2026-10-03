# Technology Stack

**Analysis Date:** 2026-01-31

## Languages

**Primary:**
- Bash 4.x+ - All orchestration, worker, and utility scripts
- Markdown - Configuration, documentation, and planning files
- JSON - Configuration files and data interchange

**Secondary:**
- YAML - Execution graphs, task definitions (parsed by scripts)

## Runtime

**Environment:**
- Unix-like shell environment (Linux, macOS, Git Bash on Windows)
- Git 2.x+
- POSIX compliance required

**Package Manager:**
- None (shell scripts only, no dependency manager)
- Uses system utilities: `bash`, `git`, `jq`, `yq` (optional)
- Lockfile: Not applicable (no packaged dependencies)

## Frameworks

**Core:**
- No traditional frameworks - custom orchestration system built on shell
- GitHub CLI (`gh`) 2.x+ - GitHub API interactions, issue/PR management
- jq 1.6+ - JSON processing and querying
- yq 4.x - YAML parsing for execution graphs

**Testing:**
- None detected - validation via shell script assertions

**Build/Dev:**
- Git worktree - Isolated development branches
- Bash sourcing pattern - Modular library system

## Key Dependencies

**Critical:**
- `gh` (GitHub CLI) - All GitHub API interactions, issue/PR operations
  - Authentication: GITHUB_TOKEN environment variable
  - Uses GitHub GraphQL API and REST API
- `jq` - JSON parsing for logs, dispatch state, configuration
- `yq` - YAML parsing for execution graphs (optional, feature-dependent)

**Infrastructure:**
- `git` - Version control, worktree management
- `bash` - Script execution engine
- `curl` - Available for HTTP operations if needed

## Configuration

**Environment:**
- `.worker/config.json` - Worker behavior (timeouts, retries, guardrails)
  - `command_timeout_seconds`: 600
  - `lock_staleness_threshold_seconds`: 1800
  - `guardrails.enabled`: true/false
  - `guardrails.default_trust_level`: 0-4
- `.claude/settings.json` - Claude Code trust and permission settings
- `.planning/config.json` - Planning behavior (mode, depth, parallelization)

**Build:**
- No build system - pure shell scripts
- Configuration files: `*.json` in `.worker/`, `.claude/`, `.planning/`

## Platform Requirements

**Development:**
- Git 2.x or newer
- Bash 4.x or newer
- GitHub CLI (`gh`) installed and authenticated
- jq 1.6+ installed
- Text editor (any)
- OS: Linux, macOS, or Windows with Git Bash/WSL

**Production:**
- Deployment target: GitHub (no separate server needed)
- Orchestration: Anthropic Claude models (via Claude Code)
- Execution: Git repositories with GitHub integration
- File storage: Git repository and `.worker/` local state directory

## External Runtime Dependencies

**Required:**
- GitHub CLI - for all GitHub API operations
- jq - for JSON processing in logs and dispatch
- git - for version control

**Optional:**
- yq - for YAML execution graph parsing (only if parallel execution enabled)
- curl - for additional HTTP operations

---

*Stack analysis: 2026-01-31*
