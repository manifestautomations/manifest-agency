# [Project Name]

> Brief one-line description of the project

## Overview

[2-3 paragraph description of what this project does, who it's for, and why it exists]

## Quick Start

### Prerequisites

- [Requirement 1]
- [Requirement 2]

### Installation

```bash
# Clone the repository (if standalone)
git clone [url]
cd [project-name]

# Install dependencies
[package manager] install

# Configure environment
cp .env.example .env
# Edit .env with your values
```

### Running Locally

```bash
# Start development server
[command]

# Run tests
[command]

# Build for production
[command]
```

## Project Structure

```
project-name/
├── src/              # Source code
├── tests/            # Test suites
├── docs/             # Documentation
├── .claude/          # AI agent configuration
├── .planning/        # Planning artifacts
├── CLAUDE.md         # Project conventions
└── README.md         # This file
```

## Development

### Branching Strategy

- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - New features
- `fix/*` - Bug fixes

### Making Changes

1. Create a feature branch from `develop`
2. Make your changes
3. Write/update tests
4. Submit a pull request

### Testing

```bash
# Run all tests
[test command]

# Run specific test suite
[test command] [suite]

# Check coverage
[coverage command]
```

## Deployment

### Environments

| Environment | URL | Branch |
|-------------|-----|--------|
| Development | [url] | `develop` |
| Staging | [url] | `staging` |
| Production | [url] | `main` |

### Deploy Process

[Describe how deployments happen]

## Documentation

- [Link to detailed docs]
- [Link to API reference]
- [Link to architecture diagrams]

## Contributing

1. Read `CLAUDE.md` for project conventions
2. Check `.planning/` for current priorities
3. Follow the branching strategy above
4. Ensure tests pass before submitting PR

## License

[License type]

---

*Part of [Manifest Automations](../README.md)*
