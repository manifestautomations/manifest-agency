# Data Enrichment Strategy for AI Sales Agents (2026)

**Context:** Powering the "Growth Stack" (pSEO + Outbound) with high-fidelity lead data.

## Core Philosophy
"Accuracy > Volume". An AI agent that sends emails to valid addresses is useful. An AI agent that spams invalid addresses burns domains.

## Recommended Stack
We will use a **Waterfall Enrichment** approach to maximize coverage and minimize cost.

### 1. Primary Source: Apollo.io
-   **Why:** Best all-in-one value ($59/mo for 2.5k credits). Good coverage of small-to-mid market.
-   **Usage:** Initial broad search and enrichment.
-   **Integration:** Official API or `apollo-node` package.

### 2. High-Fidelity Verification: Skrapp.io / Hunter.io
-   **Why:** Apollo data can be stale (~20-30% bounce rate on old leads).
-   **Usage:** Pass all Apollo emails through a dedicated verifier before sending.
-   **Integration:** `hunter.io` API (95% confidence threshold).

### 3. "Clay-style" Waterfall (Custom)
Instead of paying $149/mo for Clay, we can build a lightweight Node.js script:
1.  Try **Apollo** API.
2.  If email missing/invalid -> Try **Hunter.io** finder.
3.  If missing -> Try **Snov.io** or **Lusha** (on demand).
4.  **Enrich:** Fetch `technographics` (what software they use) to personalize the pitch.

## Implementation Plan
1.  **Lead Scoring:** Use **Prospeo** or **LinkedIn Sales Nav** export (via browser-use agent) to get initial list.
2.  **Enrichment Node:** A dedicated LangGraph node `enrich_company` that takes a domain and returns:
    -   Tech Stack (e.g., "Uses React", "Uses HubSpot")
    -   Decision Makers (CEO, CTO)
    -   Verified Emails
3.  **Personalization:** The Sales Agent uses the *Tech Stack* data to write relevant intros ("I saw you're using HubSpot...").

## Secrets Required
-   `APOLLO_API_KEY`
-   `HUNTER_API_KEY`
