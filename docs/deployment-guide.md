# Deployment Guide: Growth Stack

**Version:** 1.0
**Target:** Vercel (Next.js) + Local/VPS (Lobster Workflows)

## 1. Web Application (Vercel)

The Agency Website is a Next.js 16 application. It hosts the public site, pSEO pages, and Webhook Receivers.

### Environment Variables
Configure these in Vercel Project Settings:

| Variable | Description | Required? |
|----------|-------------|-----------|
| `OCTOLENS_WEBHOOK_SECRET` | Secret key for verifying social lead payloads. | Yes |
| `LEADSIE_WEBHOOK_SECRET` | Secret key for verifying ad account access events. | Yes |
| `VAPI_WEBHOOK_SECRET` | Secret key for securing the Voice AI handler. | Yes |
| `CRON_SECRET` | Secret for protecting `/api/cron/*` endpoints. | Yes |
| `NEXT_PUBLIC_BASE_URL` | Production URL (e.g., `https://manifest.agency`). | Yes |

### Build Settings
*   **Root Directory:** `projects/agency-website`
*   **Framework Preset:** Next.js
*   **Build Command:** `npm run build`

### Webhook Endpoints
Once deployed, register these URLs with the respective 3rd-party tools:
*   **Octolens:** `https://manifest.agency/api/webhooks/octolens`
*   **Leadsie:** `https://manifest.agency/api/webhooks/leadsie`
*   **Vapi.ai:** `https://manifest.agency/api/voice/handler` (Server URL)

---

## 2. Lobster Workflows (Local / VPS)

The `sales-triage.lobster` workflow runs on a "Worker Node" (e.g., your laptop or a dedicated VPS). It does not run on Vercel.

### Prerequisites
*   Clawdbot/Moltbot installed (`npm i -g clawdbot`).
*   `clawd` CLI available in PATH.

### Configuration
Create `workflows/.env` (do NOT commit):
```bash
APOLLO_API_KEY=...
OPENAI_API_KEY=...
```

### Running Workflows
*   **Manual Trigger:**
    ```bash
    clawd run workflows/sales-triage.lobster
    ```
*   **Cron Trigger:**
    Use system cron or Clawdbot's cron skill to schedule execution.
    ```bash
    clawd cron add "0 9 * * *" --command "clawd run workflows/sales-triage.lobster"
    ```

---

## 3. Database (Future)

Currently, the MVP uses ephemeral storage or mock data. For production:
1.  **Provision:** Supabase project.
2.  **Env:** Add `SUPABASE_URL` and `SUPABASE_KEY` to Vercel.
3.  **Migration:** Run SQL init scripts to create `leads` and `clients` tables.
