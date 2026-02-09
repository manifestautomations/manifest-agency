# Technical Specification: AI Recruiter Agent (V1)

## Overview
This document outlines the technical architecture for the "AI Recruiter" product, part of the AI Staffing vertical. The agent automates the first-round screening interview for technical and sales roles, reducing time-to-hire by 70%.

## Architecture

### 1. Core Stack
- **Frontend:** Next.js 16 (App Router) + Tailwind CSS
- **Backend:** Supabase (PostgreSQL + Auth + Edge Functions)
- **Voice AI:** Vapi.ai (Orchestration) + Deepgram (STT) + ElevenLabs (TTS)
- **LLM:** Claude 3.7 Sonnet (Reasoning & Conversation)
- **Orchestration:** LangGraph (Interview Flow Logic)

### 2. User Flow

1. **Job Setup (Recruiter):**
   - Recruiter uploads JD (Job Description).
   - System generates interview questions using `prompts/recruiter-agent.md`.
   - System provisions a unique phone number or web-call link via Vapi.

2. **Candidate Experience:**
   - Candidate receives an email/SMS with the interview link.
   - Candidate clicks link -> "Start Interview" (Web Call) OR dials number.
   - **AI Interviewer** conducts a 10-15 minute structured interview.
     - Introduction & Role Overview
     - 3-5 Technical/Behavioral Questions
     - Candidate Questions (Q&A)
     - Closing & Next Steps

3. **Post-Interview Processing:**
   - **Transcript Analysis:** System transcribes call (Vapi -> Webhook).
   - **Scoring:** LLM evaluates answers against the rubric (0-10 score).
   - **Summary:** "Hire/No Hire" recommendation generated.
   - **Notification:** Recruiter alerted via Slack/Email.

### 3. Data Model (Supabase)

```sql
-- Jobs Table
create table jobs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  questions jsonb not null, -- Array of questions
  rubric jsonb not null,    -- Scoring criteria
  status text default 'active'
);

-- Candidates Table
create table candidates (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references jobs(id),
  name text not null,
  email text not null,
  phone text,
  resume_url text,
  status text default 'applied'
);

-- Interviews Table
create table interviews (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid references candidates(id),
  vapi_call_id text,
  transcript text,
  summary text,
  score int,
  recommendation text, -- 'Strong Hire', 'Hire', 'No Hire'
  created_at timestamp with time zone default now()
);
```

### 3.1 Knowledge Graph Extraction (DeepSeek R1)

To enable advanced candidate matching and reasoning, the system uses a Knowledge Graph extracted from resumes.

**Pipeline:**
`Raw Text (PDF/Doc) -> DeepSeek R1 (Schema-Aligned Parsing) -> Graph DB (Neo4j/Supabase)`

**Process:**
1.  **Ingestion**: Candidate uploads resume.
2.  **Extraction**: DeepSeek R1 processes the text using a strict JSON schema to extract entities (Experience, Skills, Education) and infer implicit skills (e.g., "React" -> "Frontend").
3.  **Storage**: Structured data is stored in the Knowledge Graph.

For the detailed schema and reasoning strategy, see [Knowledge Graph Schema](recruiting/graph-schema.md).

### 4. Integration Points

#### Vapi Configuration (Assistant)
- **Model:** `claude-3-7-sonnet-20260224`
- **System Prompt:** See `prompts/recruiter-agent.md`
- **Tools:**
  - `endCall()`: Gracefully terminate.
  - `recordAnswer(question_id, answer_text)`: Log key responses.
  - `checkAvailability()`: Check calendar slots for next round.

#### Webhook Handlers (`/api/webhooks/vapi`)
- `function-call`: Execute server-side logic (DB updates).
- `status-update`: Log call duration/cost.
- `end-of-call-report`: Trigger post-interview analysis.

### 5. Automation Workflow (n8n / LangGraph)

1. **Trigger:** `end-of-call-report` webhook received.
2. **Step 1:** Fetch transcript.
3. **Step 2 (LLM):** "Analyze this transcript against the job rubric. Score each answer 1-10. Provide a summary."
4. **Step 3 (DB):** Update `interviews` table with results.
5. **Step 4 (Notify):** Send Slack message to `#hiring` channel: "New Candidate Screened: [Name] - Score: 8/10".

## Roadmap

### Phase 1: MVP (Web Call Only)
- Next.js Dashboard for creating jobs.
- Vapi Web SDK integration for in-browser calls.
- Simple transcript storage.

### Phase 2: Outbound (Phone)
- Bulk upload candidates.
- AI dials out: "Hi [Name], this is Alex from [Company]. I saw your application..."

### Phase 3: ATS Integration
- Sync with Greenhouse/Lever/Ashby via MCP.
- **BambooHR Integration:** Use the official BambooHR MCP server to read open roles and create candidate profiles automatically.
