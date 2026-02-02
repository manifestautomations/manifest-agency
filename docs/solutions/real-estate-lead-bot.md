# Solution Architecture: Real Estate Instant Lead Qualifier

**Vertical:** Real Estate (Agencies & Teams)
**Goal:** Respond to Zillow/Realtor.com leads in < 5 seconds, qualify intent, and book showings.
**Est. Price:** $2,000 Setup + $400/mo Retainer.

## 1. The Problem
*   **Speed to Lead:** Odds of qualifying a lead drop **21x** if you wait 30 minutes vs 5 minutes.
*   **Agent Burnout:** Agents hate calling "tire kickers" who are just browsing.
*   **Leakage:** Leads lost during weekends or open houses.

## 2. The Stack

| Component | Tool | Purpose | Cost |
|-----------|------|---------|------|
| **Trigger** | **Mailparser.io** / **Zapier** | Parse "New Lead" emails from Zillow/Realtor.com instantly. | $29/mo |
| **Outreach** | **Twilio** (SMS) + **Vapi** (Voice) | Immediate SMS acknowledgment + "Double Dial" if high intent. | Usage based |
| **Brain** | **Claude 3.5 Sonnet** | Qualification logic (Buyer vs Seller, Budget, Timeline, Pre-approval). | Usage based |
| **CRM** | **Follow Up Boss** / **HubSpot** | Source of truth. Sync status back to agent. | Existing Client Cost |
| **Booking** | **Calendly** | Scheduling listing consultations or showings. | $15/mo |

## 3. Conversation Flow (The "ISA" Agent)

### Phase 1: Immediate Capture (SMS)
*   **Trigger:** New Zillow Lead (Jane Doe, 123 Main St).
*   **AI (SMS - 10s delay):** "Hi Jane, this is Sarah with [Agency]. I saw you're interested in 123 Main St. Are you looking to see it this week?"

### Phase 2: Qualification (SMS or Voice)
*   **User:** "Yes, maybe Saturday."
*   **AI:** "Saturday works. Just so I don't waste your time—have you been pre-approved for a mortgage yet, or are you just starting?"
    *   *Constraint:* If Cash Buyer -> Skip.
*   **AI:** "And are you working with another agent exclusively right now?"
    *   *Constraint:* If Yes -> "Understood, I'll respect that relationship. Best of luck!" (Stop).

### Phase 3: The Handoff
*   **AI:** "Great. My partner Mike specializes in that neighborhood. He has a slot Saturday at 10 AM or 2 PM. Which do you prefer?"
*   **User:** "10 AM."
*   **Action:**
    1.  Book Calendly.
    2.  Tag CRM: `Qualified - Hot`.
    3.  Send Slack Alert to Mike: "HOT LEAD: Jane Doe, Pre-approved, 123 Main St, Saturday 10am."

## 4. Implementation Plan

### Week 1: Infrastructure
1.  **Email Parsing:** Set up forwarding from Zillow to Mailparser. Map fields (Name, Phone, Property).
2.  **CRM Config:** Create custom fields in Follow Up Boss for "AI Status" and "Qualification Notes".
3.  **Twilio A2P 10DLC:** Register the campaign to ensure SMS deliverability (Critical).

### Week 2: Logic & Testing
1.  **Prompting:** Build the "Helpful Assistant" persona. Strict guardrails against giving legal/pricing advice.
2.  **Latency Tuning:** Ensure SMS sends < 10s after email receipt.
3.  **Objection Handling:** "Are you a robot?" -> "I'm an automated assistant helping Mike while he's at a showing. Do you want me to have him call you?"

## 5. ROI Calculation

**Scenario:** Team of 5 agents.
*   **Leads/Month:** 200 (Zillow/PPC).
*   **Current Conversion:** 2% (4 closings).
*   **With AI (Speed to Lead < 1m):** 4% (8 closings).
*   **Avg Commission:** $10,000.
*   **Net New Revenue:** 4 extra deals * $10k = **$40,000/mo**.

**Cost:** $400/mo.
**ROI:** 100x.
