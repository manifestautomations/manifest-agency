# Product Spec: AI Staffing Firm ("Ephemeral Recruiters")

**Status:** Research / Concept
**Date:** 2026-02-04
**Source:** IDEAS.md (Tyler)

## The Core Concept
Instead of a database of candidates, we build **Ephemeral Recruiter Agents**.
For every Job Description (JD) we receive, we spin up a dedicated, autonomous agent whose *only goal* is to fill that specific role. Once filled, the agent spins down.

## Architecture

### 1. The "Hiring Manager" (Orchestrator)
- **Model:** DeepSeek R1 (Reasoning)
- **Role:** Analyzes the JD to understand *implicit* requirements (e.g., "Must have startup experience" usually means "comfortable with chaos").
- **Output:** A search strategy (keywords, companies to target, anti-patterns).

### 2. The "Sourcer" (Hunter)
- **Tools:** LinkedIn (Proxycurl), GitHub API, X (Twitter).
- **Action:** Executes the search strategy to build a "Long List" of 100 candidates.
- **Filter:** Uses standard LLM (Sonnet 3.5) to grade profiles against the JD (A/B/C tier).

### 3. The "Recruiter" (Outreach & Screening)
- **Channel:** Email / LinkedIn DM.
- **Mechanism:** "Zero-Touch" Scheduling.
- **Screening (Vapi Squad):**
    - **Agent A (Intake):** Verifies basic info (Salary, Location, Interest).
    - **Agent B (Technical):** Specialized agent (e.g., "React Expert") spins up if Agent A passes.
    - **Handoff:** Uses Vapi "Warm Transfer" to connect to Human Recruiter if the candidate is a "Tier A" match.

## The MVP (candidate-screener)

We can build a "Wedge Product" first: **The Automated Screener**.
Agencies drown in inbound resumes. We sell a tool that:
1.  Ingests Resume + JD.
2.  **DeepSeek R1** analyzes the match (Chain-of-Thought).
3.  **Vapi.ai** calls the candidate: "Hey, I saw your application. Do you have 5 minutes to confirm a few details?"
4.  Agent updates the ATS with: "Qualified / Unqualified" + Call Recording.

## Revenue Model
- **Placement Fee:** 15-20% of first year salary (Standard).
- **SaaS (The Wedge):** $500/mo per "Active Recruiter Agent".

## Why Now? (2025/2026 Trends)
- **DeepSeek R1** allows for actual *reasoning* about cultural fit, not just keyword matching.
- **Vapi.ai** latency is now low enough for natural conversation.
- **Market:** Traditional recruiters are expensive and slow.

## Tech Stack (2026 Modern Stack)
We will skip the "MVP" phase and build on the "Scale" stack immediately.

### Core
- **Orchestration:** LangGraph (State Management) + DeepSeek R1 (Planner).
- **Voice:** Vapi.ai (Squads + Warm Transfers).
- **Memory:** GraphRAG (Neo4j/FalkorDB) to map Candidate <-> Skill <-> Company relationships.
- **Tools:**
    - **Browser:** Clawdbot Browser Tool (or Puppeteer).
    - **Data:** Proxycurl (LinkedIn), GitHub API.

### The "Planner-Executor" Pattern (DeepSeek R1)
We use R1 strictly for **Planning** and **Analysis**, not tool execution.

**Prompting Strategy (Key Learnings):**
- **Zero-Shot:** Do not provide few-shot examples; it degrades reasoning.
- **No CoT Instructions:** Do not ask it to "think step by step". It does this naturally.
- **Format:** "Analyze this JD. Output a JSON Search Strategy. Do not explain."

**Flow:**
1.  **Input:** Client uploads a messy JD PDF.
2.  **Planner (R1):** "This JD asks for 'rockstar ninja', which means they are understaffed. We need a candidate who has startup experience, not just big corp tenure."
3.  **Executor (Sonnet 3.5):** Translates this insight into search queries ("Ex-YCombinator", "Series A experience").

### Why GraphRAG?
Standard RAG fails at "Find me a candidate like John but cheaper."
GraphRAG understands the *relationship*:
`John --(worked_at)--> Google --(tier)--> Tier 1`
`Jane --(worked_at)--> Dropbox --(tier)--> Tier 1`
It can infer Jane is a peer to John.

## Data Schema (Extended JSON Resume)
We extend the standard `jsonresume.org` schema with Agent-specific fields.

```json
{
  "basics": { ... },
  "work": [ ... ],
  "meta": {
    "agent_analysis": {
      "tier": "A",
      "reasoning": "Strong match for React + 3 years startup exp.",
      "culture_fit_score": 0.9,
      "flagged_concerns": ["Job hopper", "Gap in 2024"]
    },
    "voice_screen": {
      "status": "completed",
      "summary": "Candidate communicates clearly. Verified React knowledge.",
      "recording_url": "vapi_call_123.mp3",
      "transcript": "...",
      "sentiment": "Enthusiastic"
    }
  }
}
```
