# Autonomous Sales Stack (Level 2) - Implementation Plan

**Status:** Draft / Proposed
**Date:** 2026-02-01
**Goal:** Automate "Stage 2" (Scale) of the agency using low-cost, high-leverage AI tools.

## Core Stack

We will build a "Listening -> Enrichment -> Outreach" pipeline that runs 24/7.

| Component | Tool | Purpose | Cost |
|-----------|------|---------|------|
| **Listening** | `octolens` | Monitor social channels for buying intent keywords (e.g., "hiring agency", "need automation help") | $19/mo |
| **Enrichment** | `apollo` | Enrich leads found via listening with email/phone/company size | Free Tier / $49/mo |
| **CRM** | `twenty-crm` | Self-hosted Source of Truth. Stores leads, deals, and activity logs. | $0 (Self-hosted) |
| **Outreach** | `lobster` | Deterministic workflow engine to send emails/DMs (human-in-the-loop initially). | Free (Internal) |

## Workflow: The "Intent Engine"

### 1. Signal Detection (Octolens)
- **Trigger:** User posts on Twitter/Reddit/LinkedIn with keywords:
  - "looking for dev agency"
  - "automation consultant"
  - "zapier expert help"
  - "manual data entry sucks"
- **Action:** Octolens captures post + user profile. Pushes to `leads` buffer (JSON).

### 2. Enrichment (Apollo + Agent)
- **Trigger:** New lead in buffer.
- **Action:**
  - `enrichment-agent` extracts Company Name/Website from profile.
  - Queries Apollo API to get:
    - Founder email
    - Revenue range
    - Tech stack (via BuiltWith or similar)
- **Filter:** If Revenue < $500k or Tech Stack != "Compatible", discard.

### 3. Triage & Draft (Lobster)
- **Trigger:** Qualified Enriched Lead.
- **Action:** `outreach.lobster` workflow runs.
  - Generates personalized connection message (referencing their specific post).
  - Drafts email/DM.
  - **HALT:** Adds to "Review Queue" in CRM.

### 4. Human Approval (Tyler/Rich)
- **Trigger:** Daily check-in.
- **Action:** Review drafts. One-click "Approve & Send".

## Implementation Steps

1. **Install Skills:**
   - `clawdhub install octolens`
   - `clawdhub install apollo`
   - `clawdhub install twenty-crm` (or setup docker container)

2. **Configure Triggers:**
   - Setup Octolens keywords (Manifest Agency niche).

3. **Build Lobster Workflow:**
   - Create `workflows/sales-triage.lobster` to orchestrate the handoff.

## Future Upgrades (Level 3)
- **Auto-Send:** Remove human approval for high-confidence matches.
- **Voice Agent:** Retell AI calls leads who fill out forms within 30 seconds.
