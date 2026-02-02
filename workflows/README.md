# Autonomous Workflows 🦞

This directory contains **Lobster** workflows for the Manifest Agency.
Lobster is a deterministic workflow engine that allows us to run safe, "human-on-the-loop" automations.

## Prerequisites

You must have the `lobster` CLI installed.
(If running in Moltbot/Clawdbot, it is pre-installed at `tools/lobster`).

## Available Workflows

### 1. Client Onboarding (`client_onboarding.lobster`)
**Goal:** Standardize the setup of new client projects.
**Trust Level:** 2 (Human Approval Required)

```bash
lobster run workflows/client_onboarding.lobster --args-json '{"clientName": "Acme Corp", "slug": "acme-corp"}'
```

**Steps:**
1.  Scaffolds project directory from templates.
2.  Generates Trust Ledger and README.
3.  **[GATE]** Asks for human approval of file structure.
4.  Commits and pushes to GitHub.
5.  (TODO) Creates Discord channels.

### 2. Outreach Sender (`outreach_sender.lobster`)
**Goal:** Send cold emails from `scripts/outreach/drafts/` in controlled batches.
**Trust Level:** 2 (Human Approval Required)

```bash
lobster run workflows/outreach_sender.lobster --args-json '{"batchSize": 5}'
```

**Steps:**
1.  Checks for `.env` configuration.
2.  Lists the next batch of 5 drafts.
3.  **[GATE]** Shows recipients and asks for "YES" to send.
4.  Executes the sending script.

## Creating New Workflows

Workflows are `.lobster` (YAML) files.
Key features:
- `approval: required`: Pauses execution for user input.
- `condition`: Runs steps only if previous steps succeeded/approved.
- `id`: Unique step ID for variable referencing (`${{steps.id.stdout}}`).
