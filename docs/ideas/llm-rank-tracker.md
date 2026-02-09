# Product Spec: LLM Rank Tracker (GEO)

**Concept:** "SEO for the AI Era."
**Target:** Marketing Agencies (specifically our Tier 1 list).
**Status:** Idea / Research Phase.

## The Problem
Agencies spend thousands optimizing for Google Search (SEO).
But in 2026, high-intent buyers aren't Googling "best digital marketing agency".
They are asking **ChatGPT, Perplexity, and Claude**:
> "Who is the best digital agency for B2B SaaS in Austin?"

**The Gap:** Most agencies are invisible in these LLM responses. They have **0% Share of Voice** in the new search engines.

## The Solution
A "Generative Engine Optimization (GEO)" Rank Tracker.
Instead of tracking keyword rankings on Google, we track **Brand Mentions in LLM responses**.

### Core Features
1.  **Multi-Model Tracking:**
    -   Query ChatGPT (GPT-4o), Perplexity (Sonar), Claude 3.7, and Gemini.
    -   Prompt: "I am a CMO looking for a [Niche] agency. Who should I hire?"
2.  **Sentiment Analysis:**
    -   Does the LLM just list you?
    -   Does it *recommend* you?
    -   Does it mention your specific case studies?
3.  **Competitor Analysis:**
    -   "Who is winning?" (e.g., "Impactable" appears in 80% of B2B LinkedIn queries).
4.  **Reporting:**
    -   Weekly PDF report: "Your LLM Visibility Score: 12% (down 5%)".

## Technical Implementation (MVP)

### Stack
-   **Scraper:** Node.js script running periodically.
-   **APIs:**
    -   `pplx-api` (Perplexity) - Critical for "live web" results.
    -   `openai` (ChatGPT) - For checking "training data" bias.
    -   `anthropic` (Claude) - For checking enterprise/high-reasoning bias.
-   **Analyzer:** A small LLM (gpt-4o-mini) to parse the output and count mentions.

### Data Flow
1.  `cron` triggers `check-rankings.js`.
2.  Script sends 10 variations of the prompt to 3 models.
3.  Script captures responses.
4.  `analyzer` counts: "Agency Name found? Yes/No. Sentiment: Positive/Neutral."
5.  Save stats to JSON/DB.

## Why This Sells
-   **Fear of Missing Out (FOMO):** "Your competitors are being recommended by AI. You are not."
-   **New Retainer:** Agencies can sell this as a "GEO Service" to *their* clients.
-   **Low Cost to Build:** It's just API calls and string matching. High margin.

## Go-to-Market Strategy
Pitch to **Rock Salt Marketing** (Tier 1 Target):
"Ridge, you guys kill it at SEO. But have you checked your 'Perplexity Ranking'? I ran a quick audit and..."
