# AI Agent Capabilities - Manifest Automations

## 🧠 The "Earned Autonomy" Framework

We categorize agent capabilities by their level of autonomy and risk.

| Level | Role | Autonomy | Engine | Use Case |
|:---|:---|:---|:---|:---|
| **Level 1** | **The Intern** | **Draft Mode** | Lobster (Deterministic) | Scaffolding, Formatted Reports, Linting |
| **Level 2** | **The Junior** | **Co-Pilot** | LLM + Tool Use | Code Review, Unit Tests, Content Drafts |
| **Level 3** | **The Partner** | **Autopilot** | Agent Zero (Autonomous) | Complex Research, "Fix this Bug", "Optimize Ads" |

---

## 🏗️ Core Competencies

### 1. **Project Operations (Level 1)**
- **Trigger**: `scaffold-project.sh "Project Name" "slug"`
- **Output**: Full project directory structure, README, Brief, Trust Ledger, and Contract Templates.
- **Engine**: Bash / Lobster.

### 2. **Technical Architecture (Level 2)**
- **Trigger**: "Draft architecture for [Project]"
- **Output**: `architecture-v1.md`, `schema.sql`, `user-stories.md`.
- **Tools**: Markdown, SQL, Tech Stack Knowledge (T3 Mobile, Next.js, etc.).

### 3. **Documentation & Compliance (Level 1)**
- **Trigger**: "Create privacy policy", "Write onboarding checklist"
- **Output**: Legal templates, Submission checklists, Process guides.
- **Tools**: Template Library (`templates/`), Markdown.

### 4. **Code Quality & CI/CD (Level 2)**
- **Trigger**: "Setup CI"
- **Output**: GitHub Actions workflows (`.github/workflows/`), Linting rules, Type checking.
- **Tools**: YAML, ESLint, TypeScript.

### 5. **Digital Workers (Level 3 - Experimental)**
*Autonomous agents that act as team members.*

- **Ads Manager**:
  - **Tool**: Google Ads MCP / Meta Ads MCP.
  - **Action**: "Analyze last week's ROAS and pause losing keywords."
- **Outreach Specialist**:
  - **Tool**: `scripts/outreach/send-emails.js` + LLM personalization.
  - **Action**: "Find 10 leads and draft personalized intros."

---

## 🛠️ Toolbelt

- **Lobster**: Deterministic workflow engine (`workflows/*.json`) for Standard Operating Procedures (SOPs).
- **Agent Zero**: Dockerized autonomous environment for complex, multi-step problem solving.
- **Moltbot Skills**: Modular capabilities (e.g., `github`, `marketing-mode`) loaded on demand.

---

*Last updated: 2026-01-30*
