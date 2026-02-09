# Technical Specification: AI SDR Agent (V1)

## Overview
This document outlines the technical architecture for the "AI SDR" (Sales Development Representative) product. This agent serves two primary functions:
1.  **Inbound Response:** Instantly engaging leads who fill out contact forms ("Speed to Lead").
2.  **Outbound Prospecting:** Autonomous list building and cold outreach.

## Architecture

### 1. Core Stack
-   **Orchestration:** LangGraph (State machine for conversation flow).
-   **Voice AI:** Vapi.ai (for outbound dialing/inbound handling).
-   **LLM:** Claude 3.7 Sonnet (Drafting & Objection Handling).
-   **Data:** Apollo.io (Enrichment) + Scraping (Browser Use).
-   **Integration:** MCP Servers (HubSpot, Salesforce).

### 2. User Flows

#### A. The "Speed to Lead" Flow (Inbound)
1.  **Trigger:** Prospect fills out a Typeform/Webflow form.
2.  **Action:** Webhook hits `api/webhooks/inbound-lead`.
3.  **Enrichment:** Agent pings Apollo API to get company size, tech stack, and decision maker verification.
4.  **Decision Branch:**
    -   *High Value (Enterprise):* **Immediate Vapi Call.** "Hi [Name], I just saw your inquiry about [Topic]..."
    -   *Mid Value (SMB):* **Personalized Email.** Drafted by Claude 3.7, sent via Gmail/Outlook.
    -   *Low Value (Spam/OOS):* **Ignore/Auto-reject.**
5.  **Outcome:** Meeting booked in Calendly or Lead status updated in CRM.

#### B. The "Hunter" Flow (Outbound)
1.  **Trigger:** User defines a territory (e.g., "Dental Clinics in Texas").
2.  **Search:** Agent uses `google_maps` or `apollo` tool to build a list.
3.  **Enrichment:** Verifies email deliverability (Hunter.io) and phone numbers.
4.  **Campaign:**
    -   **Step 1:** Cold Email (Value-add resource).
    -   **Step 2 (Day 2):** LinkedIn Connection Request (if URL known).
    -   **Step 3 (Day 4):** Vapi Phone Call (if number available). "Hi, I sent you an email about..."
5.  **Handoff:** If positive sentiment detected -> Transfer to human Account Executive.

### 3. Data Model (Supabase)

```sql
-- Campaigns Table
create table campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  target_audience jsonb, -- e.g., { "industry": "Dental", "location": "TX" }
  status text default 'draft' -- draft, active, paused, completed
);

-- Leads Table
create table leads (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid references campaigns(id),
  first_name text,
  last_name text,
  email text,
  phone text,
  company text,
  enrichment_data jsonb, -- Apollo data
  score int, -- 0-100 likelihood to buy
  status text default 'new' -- new, contacted, interested, booked, disqualified
);

-- Activities Table
create table activities (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references leads(id),
  type text, -- email, call, sms, linkedin
  direction text, -- inbound, outbound
  content text, -- email body or call transcript summary
  sentiment text, -- positive, negative, neutral
  created_at timestamp with time zone default now()
);
```

### 4. Integration Strategy (MCP)

Instead of building custom point-to-point integrations, the AI SDR uses **Model Context Protocol (MCP)** servers to talk to CRMs.

-   **HubSpot MCP:** `read_contact`, `create_task`, `update_deal_stage`.
-   **Salesforce MCP:** `soql_query`, `create_lead`.
-   **Slack MCP:** `post_message` (for "Hot Lead" alerts).

### 5. Compliance & Guardrails
-   **Timezone Check:** Outbound calls only allowed 9am-5pm local time.
-   **DNC List:** Checks phone numbers against Do Not Call registry cache.
-   **Email Limits:** Max 50 emails/day per mailbox to preserve domain health (Smart Lead warming).

## Roadmap

### Phase 1: Inbound Pilot
- Webhook listener for form fills.
- Instant email response generation.
- Slack notification.

### Phase 2: Voice Outbound
- Vapi integration for follow-up calls on warm leads.
- "Press 1 to book" functionality.

### Phase 3: Full Autonomy
- Autonomous list building.
- Multi-channel orchestration (Email + Call + LinkedIn).
