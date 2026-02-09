# Solution Architecture: AI Voice Receptionist for Dental Clinics

**Vertical:** Dental / Healthcare
**Goal:** Automate 100% of after-hours calls and 60% of business-hour calls (scheduling, FAQs).
**Est. Price:** $1,500 Setup + $300/mo Retainer.

## 1. The Stack

| Component | Tool | Purpose | Cost |
|-----------|------|---------|------|
| **Telephony** | **Vapi.ai** (or Retell AI) | Voice interaction, latency handling, interruption handling. | ~$0.05/min |
| **LLM Brain** | **Claude 3.5 Sonnet** (via Vapi) | Conversation logic, empathy, scheduling constraints. | Usage based |
| **Booking** | **Cal.com** (Platform) | Real-time calendar syncing, double-booking prevention. | $15/mo |
| **Orchestration** | **n8n** (Self-hosted) | Connecting Vapi Webhooks -> CRM (Dentrix/EagleSoft via API bridge). | $5/mo (VPS) |
| **Knowledge** | **Vector Store** (Pinecone) | Storing clinic specifics (insurance accepted, parking, pricing). | Free Tier |

## 2. Conversation Flow

### Phase 1: Triage (The "Receptionist")
*System answers immediately.*
**AI:** "Thanks for calling [Clinic Name]. Are you calling to book an appointment or do you have a question?"

*   **Path A: Appointment** -> Go to Phase 2.
*   **Path B: Emergency** -> "I understand. I'm connecting you to Dr. Smith's emergency line." -> **Warm Transfer**.
*   **Path C: Question** -> Query Knowledge Base (Insurance/Hours) -> Answer -> "Would you like to book a visit?"

### Phase 2: Scheduling (The "Coordinator")
*   **AI:** "Great. Are you a new patient or returning?"
*   **AI:** "We have openings this Tuesday at 10 AM or Thursday at 2 PM. Do either work?"
*   **User:** "How about next Monday?"
*   **AI:** *Checks Cal.com API* -> "I have Monday at 9:30 AM open."
*   **User:** "I'll take it."

### Phase 3: Confirmation (The "Closer")
*   **AI:** "Done. Monday the 12th at 9:30 AM. I'm sending a confirmation text now."
*   **Action:** Trigger `n8n` webhook -> SMS sent -> Calendar Event created.

## 3. Implementation Plan (2 Week Sprint)

### Week 1: Setup & Training
1.  **Phone Number Procurement:** Buy Twilio number, connect to Vapi.
2.  **Prompt Engineering:** configure the "Receptionist Persona" (warm, professional, empathetic).
3.  **Knowledge Base Ingestion:** PDF scrape of client's "New Patient Packet" and website FAQs.
4.  **Calendar Integration:** Connect Cal.com to the Doctor's Google/Outlook calendar.

### Week 2: Integration & Testing
1.  **Tool Construction:** Build Vapi tools for `checkAvailability` and `bookSlot` hitting Cal.com API.
2.  **Stress Testing:** Simulate 50 calls with various accents and background noise.
3.  **Handoff Protocols:** Define "Emergency" keywords that trigger immediate SMS to office manager.

## 4. ROI Calculation (For Sales)

**Scenario:** Small clinic, 2 dentists.
*   **Missed Calls/Month:** 40 (After hours + busy line).
*   **Avg. Patient Value:** $450 (First visit + hygiene).
*   **Conversion Rate:** 25% (Conservative).
*   **Monthly Revenue Saved:** 10 calls * $450 = **$4,500/mo**.

**Cost to Client:** $300/mo.
**ROI:** 15x.
