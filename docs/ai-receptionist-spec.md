# Technical Specification: AI Receptionist Agent (V1)

## Overview
This document outlines the technical architecture for the "AI Receptionist" product. Unlike the Recruiter or SDR, this agent is **Inbound-Only** and designed for high-volume, simple tasks: capturing leads and booking appointments for service-based businesses (Dental, Legal, Home Services).

## Architecture

### 1. Core Stack
-   **Voice AI:** Vapi.ai (Telephony & Orchestration).
-   **LLM:** Claude 3.5 Sonnet (Fast, polite, instruction-following).
-   **Backend:** n8n (Low-code workflow automation) or Next.js API Routes.
-   **Database:** Supabase (Tenants, Call Logs) + Airtable (Client View).

### 2. User Flow (The "Missed Call" Rescue)

1.  **Trigger:** Client (Dentist) forwards missed calls to a Twilio number managed by Vapi.
2.  **Greeting:** "Thanks for calling Dr. Smith's office. I'm the automated assistant. Are you calling to book an appointment or ask a question?"
3.  **Intent Classification:**
    -   **Booking:** "I need a checkup." -> Checks Calendar Availability.
    -   **Emergency:** "I'm in pain." -> Flags as urgent, sends SMS to Dr. Smith.
    -   **FAQ:** "Do you take Delta Dental?" -> Queries Knowledge Base (RAG).
4.  **Action:**
    -   If Booking: "I have Tuesday at 2pm or Wednesday at 10am." -> Books slot.
    -   If FAQ: Answers question based on `context.txt`.
5.  **Post-Call:**
    -   Sends SMS confirmation to caller.
    -   Logs call in Dashboard.

### 3. Data Model (Supabase - Multi-Tenant)

```sql
-- Agents Table (One per Client)
create table agents (
  id uuid primary key default gen_random_uuid(),
  client_name text not null,
  vapi_assistant_id text not null,
  twilio_number text not null,
  calendar_integration_id uuid,
  knowledge_base text, -- FAQ content
  business_hours jsonb -- { "mon": ["09:00", "17:00"] }
);

-- Calls Table
create table calls (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid references agents(id),
  caller_number text,
  duration_seconds int,
  recording_url text,
  transcript text,
  outcome text, -- 'booked', 'inquiry', 'spam'
  created_at timestamp with time zone default now()
);
```

### 4. Integration Points

#### Calendar (The Hard Part)
-   We use **Cal.com Platform** or **Google Calendar API** via MCP.
-   **Tool:** `checkAvailability(start_date, end_date)`
-   **Tool:** `bookAppointment(name, phone, slot_time)`

#### Knowledge Base (RAG)
-   Simple: Upload a `.txt` file to Vapi's "Knowledge Base" feature.
-   Complex: Custom vector store (pgvector) for large FAQs. (Start with Simple).

### 5. Implementation Steps (MVP)

1.  **Vapi Setup:** Create a "Base Assistant" prompt that enforces brevity and politeness.
2.  **n8n Workflow:**
    -   Webhook from Vapi `function-call`.
    -   Node: "Get Free Slots" (Google Calendar).
    -   Return: JSON list of slots.
3.  **Twilio:** Buy number, configure Voice URL to Vapi SIP URI.

## Roadmap

### Phase 1: The "Simple Scheduler"
-   Fixed availability slots.
-   Basic FAQ (Hours, Location, Insurance).

### Phase 2: The "Smart Triage"
-   Emergency detection (Sentiment Analysis).
-   Escalation to human receptionist (Warm Transfer).

### Phase 3: White-Label Dashboard
-   Client portal to view logs and listen to calls.
-   "Override" mode to take over live calls.
