# Solution Architecture: AI Recruiter (Candidate Screener)

**Vertical:** Recruiting / Staffing
**Goal:** Screen 100% of applicants instantly, score them against JD, and schedule interviews for top 10%.
**Est. Price:** $2,500 Setup + $500/mo Retainer.

## 1. The Problem
*   **Resume Fatigue:** Recruiters spend 6s per resume. Good candidates are missed.
*   **Ghosting:** High-quality candidates accept other offers while waiting 2 weeks for a reply.
*   **Bias:** Unconscious bias in manual screening.

## 2. The Stack

| Component | Tool | Purpose | Cost |
|-----------|------|---------|------|
| **Ingestion** | **Webhook** / **Email Parsing** | Receive applications from Greenhouse/Lever/Ashby. | Included |
| **Analysis** | **Claude 3.5 Sonnet** | Extract skills, experience, and match against Job Description. | Usage based |
| **Outreach** | **Lobster** (Workflow) | Orchestrate email sequence (Reject / Request Info / Schedule). | Free |
| **Voice** | **Vapi** (Optional) | 5-minute phone screen for communication skills. | ~$0.10/candidate |
| **Scheduling** | **Calendly** | Book recruiter screen. | $15/mo |

## 3. Workflow (The "Recruiter Agent")

### Phase 1: Resume Scoring (Instant)
*   **Trigger:** New Application.
*   **AI Analysis:**
    *   Parse Resume PDF.
    *   Compare to Job Description (JD).
    *   **Score (0-100):** Based on Required Skills, Years of Exp, Location.
    *   **Output:** JSON `{ "score": 85, "missing": ["React Native"], "strengths": ["Senior Leadership"] }`

### Phase 2: Automated Actions
*   **Score < 50 (Mismatch):**
    *   Action: Wait 48 hours -> Send polite rejection email.
*   **Score 50-80 (Potential):**
    *   Action: Send "Clarification Questions" email ("Do you have experience with X?").
*   **Score > 80 (Top Tier):**
    *   Action: Send "Fast Track" SMS/Email -> "Impressive background. Let's chat."

### Phase 3: The Phone Screen (Optional Vapi Add-on)
*   **Agent:** "Hi [Name], I'm the AI screener for [Company]. Do you have 5 minutes to verify some details?"
*   **Questions:**
    1.  "Are you authorized to work in the US?"
    2.  "What is your notice period?"
    3.  "Why are you leaving your current role?"
*   **Outcome:** If answers pass -> Book Calendly immediately.

## 4. Implementation Plan

### Week 1: ATS Integration
1.  **Connect:** API keys for Greenhouse/Lever (or email parsing fallback).
2.  **Scoring Logic:** Tune the prompt to match recruiter's mental model (e.g., "Value startups over corporate").

### Week 2: Build & Test
1.  **Lobster Workflow:** Build the deterministic routing logic.
2.  **Backtesting:** Run the AI against 50 past successful/failed candidates to calibrate scoring.

## 5. ROI Calculation

**Scenario:** Staffing Agency (5 Recruiters).
*   **Apps/Month:** 2,000.
*   **Screening Time:** 5 mins/resume = 166 hours/mo (1 full-time hire).
*   **Placement Fee:** $20,000.
*   **Missed Placements:** 1/mo due to slow speed.
*   **Value:** 166 hours saved + $20k extra revenue = **$30,000/mo**.

**Cost:** $500/mo.
**ROI:** 60x.
