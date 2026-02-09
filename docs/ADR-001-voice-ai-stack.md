# ADR 001: Voice AI Stack Selection

**Status:** Accepted
**Date:** 2026-02-13
**Author:** Rich (AI Assistant)

## Context
For our **AI Staffing (Recruiter)** and **Growth (SDR)** verticals, we need a voice agent capability that mimics human conversation. The critical requirements are:
1.  **Latency:** Must be sub-800ms to feel natural.
2.  **Interruption Handling:** The agent must stop speaking immediately when the user interrupts.
3.  **Reliability:** Turn-taking logic must be robust (not talking over the user).
4.  **Developer Experience:** We need to move fast (Milestone 1) without building a custom WebSocket infrastructure from scratch.

## Options Considered

### 1. Custom Stack (LiveKit + Deepgram + LangChain)
-   **Pros:** Full control, open source (LiveKit), no platform fees (pay for usage only).
-   **Cons:** High complexity. We have to build our own VAD (Voice Activity Detection), interruption logic, and orchestration. High maintenance burden.

### 2. Vapi (Managed Orchestration)
-   **Pros:** "Stripe for Voice". Handles VAD, turn-taking, and tool-calling out of the box. Visual builder ("Flow Studio") for quick prototyping + API for devs. Low code + High Code hybrid.
-   **Cons:** Platform fee ($0.05/min markup). Vendor dependence.

### 3. Retell AI
-   **Pros:** Excellent "human-like" turn-taking models.
-   **Cons:** Less developer flexibility compared to Vapi's API-first approach.

## Decision
We will use **Vapi** as our orchestration layer for the MVP.

**The Stack:**
-   **Orchestration:** [Vapi](https://vapi.ai)
-   **Speech-to-Text (STT):** [AssemblyAI](https://www.assemblyai.com) (Universal-Streaming model) - Selected for superior accuracy and keyword boosting (industry terms).
-   **LLM (Brain):** [Claude 3.7 Sonnet](https://anthropic.com) - Selected for superior reasoning and tool-use capabilities (81.2% retail benchmark) vs OpenAI o3-mini.
-   **Text-to-Speech (TTS):** [ElevenLabs](https://elevenlabs.io) (Turbo v2.5) - For lowest latency, high-quality emotive voices.

## Rationale
1.  **Speed to Market:** Vapi allows us to ship a working voice agent in days, not weeks.
2.  **Latency:** Vapi's server-side optimization + AssemblyAI Streaming + ElevenLabs Turbo is a proven low-latency stack.
3.  **Flexibility:** We can switch LLMs or TTS providers via config in Vapi if pricing/quality changes (e.g., swapping to Deepgram Aura or OpenAI Voice later).
4.  **Claude 3.7:** Our "AI Recruiter" needs to handle complex resume screening questions. Claude 3.7's reasoning prevents the "robotic script reader" vibe.

## Consequences
-   **Cost:** Running Vapi + Claude + ElevenLabs is expensive (~$0.15-$0.25/min). We must validate unit economics before high-volume scaling.
-   **Mitigation:** For high-volume, low-complexity calls (e.g., simple confirmation), we can swap Claude 3.7 for `haiku` or `o3-mini` to reduce costs.
