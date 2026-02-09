# Architecture: Growth Stack & Dashboard Integration

## Overview
This document outlines the technical architecture for the "Growth Stack" (pSEO + Sales Automation) and its integration with the Clawdbot Gateway.

## The "Headless Agent" Pattern

To enable our Next.js dashboard to trigger complex agentic workflows (like "Enrich Lead" or "Draft Email"), we use Clawdbot's `/tools/invoke` HTTP endpoint. This allows the frontend to act as a remote control for the agent.

### 1. API Flow
1.  **User Action:** Admin clicks "Run Enrichment" on a lead in the Next.js Dashboard.
2.  **Next.js API Route:** `POST /api/agents/invoke` receives the request.
3.  **Clawdbot Gateway:** The API route forwards the request to `http://localhost:18789/tools/invoke`.
    -   **Headers:** `Authorization: Bearer <CLAWDBOT_GATEWAY_TOKEN>`
    -   **Body:**
        ```json
        {
          "tool": "sessions_spawn",
          "action": "run",
          "args": {
            "task": "Enrich lead: alex@scaleupsaas.com using Apollo and save to Supabase.",
            "model": "claude-3-7-sonnet"
          }
        }
        ```
4.  **Agent Execution:** Clawdbot spawns a sub-agent to perform the task asynchronously.
5.  **Feedback:** The dashboard polls the database (Supabase) for updates, or listens for a webhook from the agent.

### 2. Why this approach?
-   **Security:** The API token stays server-side in Next.js (`.env`).
-   **Decoupling:** The dashboard doesn't need to know *how* to enrich a lead, only *that* the agent can do it.
-   **Scalability:** We can offload long-running tasks to background agents without blocking the UI.

## pSEO Architecture (Programmatic SEO)

### 1. Data Source
-   **Content:** `content/pseo-data.json` (Structured data: Industries, Locations, Pain Points).
-   **Templates:** Markdown/MDX templates in `src/app/services/[industry]/[location]/page.tsx`.

### 2. Build Process (SSG)
-   Next.js `generateStaticParams()` iterates over the Cartesian product of `Industries x Locations`.
-   **Scale:** 10 Industries x 50 Cities = 500 Landing Pages generated at build time.
-   **Deployment:** Vercel (Edge Network) for sub-100ms TTFB.

### 3. Conversion Loop
-   Each page features a specific "AI Demo" CTA (e.g., "Hear the Dental AI Receptionist").
-   **Capture:** Vapi Web SDK or Typeform embedded on the page.
-   **Handoff:** Lead data sent to the "AI SDR" workflow via Webhook.
