# Workspace Scripts

Scripts for managing workspaces in the Manifest Automations agency.

## Source of Truth

Workspaces are managed as **git submodules**. The `.gitmodules` file is the single source of truth for workspace registration.

## Available Scripts

### workspace-list.sh

List all registered workspaces discovered from `.gitmodules`.

**Usage:**
```bash
# Human-readable table output
./scripts/workspace/workspace-list.sh

# Machine-readable JSON output
./scripts/workspace/workspace-list.sh --porcelain
```

**Example output:**
```
Registered Workspaces
=====================

NAME                           PATH                                STATUS
----                           ----                                ------
project-a                      projects/project-a                  initialized
project-b                      projects/project-b                  not initialized

Total: 2 workspace(s)
```

**Porcelain output:**
```json
[
  {"name": "project-a", "path": "projects/project-a", "url": "../project-a.git", "status": "initialized"},
  {"name": "project-b", "path": "projects/project-b", "url": "../project-b.git", "status": "not-initialized"}
]
```

### workspace-resolve.sh

Resolve workspace names and aliases to filesystem paths.

**Resolution Order:**
1. Exact directory match at `projects/<name>/`
2. Submodule path suffix match from `.gitmodules` (case-insensitive)
3. Alias lookup from `.worker/config.json` (case-insensitive)

**Usage:**
```bash
# Resolve by exact name
./scripts/workspace/workspace-resolve.sh project-a

# Resolve by alias (case-insensitive)
./scripts/workspace/workspace-resolve.sh PA
```

**Exit codes:**
- `0`: Workspace found, absolute path printed to stdout
- `1`: Workspace not found, error message and suggestions printed to stderr

**Example:**
```bash
# Success
$ ./scripts/workspace/workspace-resolve.sh project-a
/home/user/manifest-automations/projects/project-a

# Failure
$ ./scripts/workspace/workspace-resolve.sh nonexistent
Workspace 'nonexistent' not found.
Valid workspaces:
  - projects/project-a
  - projects/project-b
```

## Configuration

Workspace aliases are configured in `.worker/config.json`:

```json
{
  "workspaces": {
    "aliases": [
      {"alias": "pa", "path": "projects/project-a"},
      {"alias": "main", "path": "projects/main-client"}
    ],
    "projects_dir": "projects"
  }
}
```

Aliases are matched **case-insensitively**, so `PA`, `pa`, and `Pa` all resolve to the same workspace.

## Adding Workspaces

To add a new workspace as a submodule:

```bash
# Add submodule
git submodule add ../project-name.git projects/project-name

# Set branch tracking
git config -f .gitmodules submodule.projects/project-name.branch main

# Commit the registration
git add .gitmodules projects/project-name
git commit -m "feat: add project-name workspace"
```

### workspace-validate.sh

Validate that a workspace has the required structure for dispatch operations.

**Required (causes INVALID):**
- Valid git repository
- `.planning/trust-ledger.md` exists

**Optional (warnings only):**
- `.claude/` directory

**Usage:**
```bash
# Via sourcing (recommended for scripts)
source scripts/workspace/workspace-validate.sh
validate_workspace_structure "/path/to/workspace"

# Quick validation
bash -c 'source scripts/workspace/workspace-validate.sh; validate_workspace_structure "/path/to/workspace"'
```

**Example output (valid workspace):**
```
Validating: project-name
Path: /home/user/projects/project-name

Status: VALID
```

**Example output (invalid workspace):**
```
Validating: broken-project
Path: /home/user/projects/broken-project

Status: INVALID

Required items missing:
  [ERROR] Missing .planning/trust-ledger.md

Warnings:
  [WARN] Missing .claude/ directory (optional)
```

**Exit codes:**
- `0`: All required structure present (may have warnings)
- `1`: Required structure missing or path doesn't exist

### workspace-health.sh

Check health status of workspaces before dispatch operations.

**Health Stages:**

1. **Git State**
   - Not a git repo -> RED
   - Detached HEAD -> YELLOW
   - Uncommitted changes -> YELLOW
   - Untracked source files -> YELLOW

2. **Structure**
   - Missing .planning/ -> RED
   - Missing trust ledger -> RED
   - Missing .claude/ -> YELLOW

3. **Trust Ledger Format**
   - Missing required headers -> YELLOW

**Status Meanings:**

| Status | Meaning | Dispatch |
|--------|---------|----------|
| GREEN | Healthy, no issues | Allowed |
| YELLOW | Warnings present | Allowed with caution |
| RED | Blocking issues | Blocked |

**Usage:**
```bash
# Check all registered workspaces
bash -c 'source scripts/workspace/workspace-health.sh; check_all_workspaces'

# Check single workspace
bash -c 'source scripts/workspace/workspace-health.sh; print_workspace_health "/path/to/workspace"'

# Check by workspace name
bash -c 'source scripts/workspace/workspace-health.sh; _workspace_health_main "project-name"'
```

**Example output (all workspaces):**
```
Workspace Health Status
=======================

[OK]   project-a
[WARN] project-b:                      Uncommitted changes present
[ERR]  project-c:                      Missing trust ledger
[SKIP] project-d                       (not initialized)

Some workspaces have blocking issues (RED status).
```

**Example output (single workspace):**
```
Workspace: project-name
Path: /home/user/projects/project-name
Status: YELLOW

Issues:
  - Uncommitted changes present
  - Missing .claude/ directory (optional)
```

**Exit codes:**
- `0`: All checked workspaces are GREEN or YELLOW
- `1`: At least one workspace is RED (or path not found)

## Sourcing Functions

All scripts export functions that can be sourced by other scripts:

```bash
# Source workspace-list.sh
source scripts/workspace/workspace-list.sh
list_workspaces --porcelain | jq '.[] | .name'

# Source workspace-resolve.sh
source scripts/workspace/workspace-resolve.sh
if path=$(resolve_workspace "project-a"); then
    cd "$path"
    # ... work in workspace
fi

# Source workspace-validate.sh
source scripts/workspace/workspace-validate.sh
if validate_workspace_structure "$path"; then
    echo "Workspace is valid"
else
    echo "Workspace has issues"
fi

# Source workspace-health.sh
source scripts/workspace/workspace-health.sh
check_workspace_health "$path"
if [[ "$HEALTH_STATUS" == "RED" ]]; then
    echo "Cannot dispatch - workspace has blocking issues"
    echo "Issues: ${HEALTH_ISSUES[*]}"
fi
```

**Note:** On some platforms (Windows/Git Bash), direct invocation via `bash script.sh args` may not work correctly. Use the sourcing pattern shown above for reliable cross-platform behavior.
