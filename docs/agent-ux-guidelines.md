# Agentic UX Design Guidelines (2026)

**Context:** Designing the Client Portal for Manifest Agency's "Autonomous Workforce".
**Goal:** Move beyond "Chatbot" interfaces to "Agent Management" interfaces.

## Core Philosophy
"Don't just talk to the agent; manage the workforce."

## Key Design Patterns

### 1. The Supervisor-Worker Pattern
Users should not interact with 10 different agents. They interact with one **Supervisor** (e.g., "Account Manager") who delegates tasks.
-   **UI Implication:** Show the delegation chain.
-   *Example:* User asks "Find me leads." -> Supervisor says "Deploying Research Agent..." -> UI shows a spinner next to "Research Agent" -> Supervisor says "Research complete. Deploying Email Agent..."

### 2. The "Clue" Loop (Evidence -> Hypothesis -> Action)
Agents shouldn't just guess. They should show their work.
1.  **Gather Evidence:** "I scanned 500 profiles." (Show stats).
2.  **Form Hypothesis:** "I believe 50 of these are high-intent." (Show list).
3.  **User Confirmation:** "Proceed with outreach?" (Approve/Reject button).
4.  **Action:** "Sending emails..." (Progress bar).

### 3. Asynchronous State
Agents take time. The UI must handle long-running tasks without hanging.
-   **Notifications:** "Agent X finished task Y while you were away."
-   **Activity Feed:** A scrolling log of agent actions (like a terminal but readable).
-   **State Indicators:** `Thinking`, `Working`, `Waiting for Input`, `Paused`, `Error`.

### 4. Human-in-the-Loop Controls
Users must feel in control of the "Sorcerer's Apprentice".
-   **The "Emergency Stop" Button:** Immediately halt all agent activity.
-   **The "Pause" Button:** Pause execution to inspect current state.
-   **Permission Levels:**
    -   *Autonomous:* Agent acts without asking.
    -   *Semi-Autonomous:* Agent asks before *high-risk* actions (spending money, sending emails).
    -   *Manual:* Agent only suggests; human acts.

## Component Library Ideas
-   **Agent Card:** Status dot, current task, recent logs.
-   **Reasoning Block:** A collapsible section showing the LLM's `<think>` trace (sanitized).
-   **Decision Node:** A card asking the user for a decision (A/B/C).
