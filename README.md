# Manifest Automations

An AI-powered development agency that orchestrates multiple projects through earned autonomy.

## Vision

Manifest Automations is a new paradigm for AI-assisted software development. Rather than treating AI as a simple tool, we implement a structured trust system where AI agents earn progressive autonomy through demonstrated competence.

**Core Offerings:**
1.  **AI Staffing (Voice Agents):** White-label AI Receptionists, Recruiters, and SDRs.
2.  **Growth Stack:** Programmatic SEO (pSEO) and Automated Outbound.
3.  **Custom Development:** AI-native web apps (Next.js, Supabase, Vapi).

## Project Structure

```
Manifest Automations/
├── commands/            # CLI-style prompt triggers
├── content/             # Public-facing content (Blogs, Case Studies)
├── docs/                # Strategy & Architecture (ADRs, Specs)
├── projects/            # Client Projects & Internal Products
├── prompts/             # System prompts for AI Agents (Vapi, etc.)
├── schemas/             # Data models (Knowledge Graph, JSON schemas)
├── scripts/             # Automation scripts (Outreach, Enrichment)
├── templates/           # Asset Library (Contracts, Email Sequences)
├── workflows/           # Lobster automation workflows 🦞
└── CLAUDE.md            # Agency conventions & Trust System
```

## Key Verticals

### 1. AI Staffing (Voice AI)
-   **Tech Stack:** Vapi.ai (Orchestration), Claude 3.7 (Brain), ElevenLabs (Voice).
-   **Products:**
    -   **AI Recruiter:** Autonomous resume screening and phone interviews. [Spec](docs/ai-recruiter-spec.md)
    -   **AI SDR:** Cold calling and lead qualification. [Spec](docs/ai-sdr-spec.md)
    -   **AI Receptionist:** 24/7 inbound call handling for SMBs. [Spec](docs/ai-receptionist-spec.md)

### 2. Growth Stack (pSEO + Outbound)
-   **Tech Stack:** Next.js (SSG), Apollo.io (Enrichment), LangGraph (Agent Logic).
-   **Products:**
    -   **pSEO Engine:** Generates 1,000s of "Automated Reporting for [Niche]" pages.
    -   **Sales Triage:** Enriches inbound leads and drafts personalized outreach.
    -   **LLM Rank Tracker:** Tracks "Share of Voice" on ChatGPT/Perplexity.

## Trust System

The agency operates on a 5-level trust model defined in `CLAUDE.md`:

| Level | Name | Description |
|-------|------|-------------|
| 0 | No Trust | Read-only, explicit approval for all actions |
| 1 | Basic Trust | Can suggest changes, no direct modification |
| 2 | Limited Autonomy | Can edit with verification |
| 3 | Standard Autonomy | Execute plans with checkpoints |
| 4 | Full Autonomy | Trusted for complex operations |

## Getting Started

### For Humans
1.  Clone this repository.
2.  Review `CLAUDE.md` for conventions.
3.  Check `STATUS.md` for current agency status.
4.  Run `npm install` in `scripts/` directories to set up automation tools.

### For AI Agents
1.  Read `CLAUDE.md` completely.
2.  Check `HEARTBEAT.md` for current priorities.
3.  Execute tasks in `PROACTIVE_QUEUE.md`.
4.  Document all major decisions in `docs/ADR-XXX.md`.

## Contributing
1.  All contributions start at Trust Level 0.
2.  Follow the workflow hierarchy.
3.  Document everything in `docs/`.
4.  Request review at checkpoints.

## License
Proprietary - Manifest Automations

---

*Building the future of AI-assisted development, one earned trust level at a time.*
