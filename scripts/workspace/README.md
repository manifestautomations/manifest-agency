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

## Sourcing Functions

Both scripts export functions that can be sourced by other scripts:

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
```
