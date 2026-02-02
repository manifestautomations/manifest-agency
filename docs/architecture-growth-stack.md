# Growth Stack Architecture

**Version:** 1.0
**Status:** Implemented in `feat/growth-stack`

## Overview
The Growth Stack is a set of automated workflows designed to generate leads, onboard clients, and handle voice calls without human intervention.

## Components

### 1. Sales Automation (Octolens)
*   **Goal:** Capture high-intent leads from social media (Twitter/Reddit).
*   **Flow:**
    1.  **Octolens** detects keyword ("reporting nightmare", "agency burnout").
    2.  **Webhook** fires to `/api/webhooks/octolens`.
    3.  **Next.js** verifies signature and logs lead.
    4.  *(Future)* Trigger `sales-triage.lobster` to draft outreach.

### 2. Zero-Touch Onboarding (Leadsie)
*   **Goal:** Grant ad account access in 1 click.
*   **Flow:**
    1.  Client clicks `leadsie.com/request/...`.
    2.  **Leadsie** handles OAuth with Meta/Google.
    3.  **Webhook** fires to `/api/webhooks/leadsie`.
    4.  **Next.js** triggers Airbyte to create a new Source for that ad account.
    5.  **BigQuery** dataset is created automatically.

### 3. Voice Receptionist (Vapi.ai)
*   **Goal:** Handle inbound calls 24/7.
*   **Flow:**
    1.  **Vapi.ai** receives call.
    2.  **LLM** determines intent (Book Appointment vs. General Q).
    3.  **Function Call** hits `/api/voice/handler`.
    4.  **Next.js** checks Calendar API for availability.
    5.  **Vapi** speaks response via ElevenLabs.

## Security
*   All webhooks are protected by signature verification (HMAC SHA256) or Secret Tokens.
*   API Routes run on Next.js Edge (where possible) for low latency.

## Future Improvements
*   **Event Logging:** Persist all webhook events to Supabase for debugging.
*   **Retry Logic:** Use QStash (Upstash) to retry failed webhook processing.
