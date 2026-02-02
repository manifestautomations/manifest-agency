# Solution Architecture: E-commerce Support Agent (Ticket Deflection)

**Vertical:** E-commerce (Shopify/Magento Brands)
**Goal:** Automate 70% of Level 1 support tickets ("Where is my order?", "Return policy") instantly.
**Est. Price:** $3,000 Setup + $500/mo Retainer.

## 1. The Problem
*   **Ticket Volume:** Support teams drown in "WISMO" (Where Is My Order) tickets during peak seasons.
*   **Response Time:** 24h response time kills conversion and loyalty.
*   **Cost:** Humans are too expensive for copy-pasting tracking numbers.

## 2. The Stack

| Component | Tool | Purpose | Cost |
|-----------|------|---------|------|
| **Channel** | **Gorgias** / **Zendesk** | The Helpdesk. We hook into this via API/Webhooks. | Client pays |
| **Brain** | **Claude 3.5 Haiku** | Fast, cheap reasoning for simple queries. | Usage based |
| **Data** | **Shopify API** | Source of truth for Order Status, Tracking, Inventory. | Included |
| **Orchestration** | **LangChain** / **n8n** | Logic routing: If "WISMO" -> Check Shopify -> Reply. | $5-20/mo |
| **Vector Store** | **Pinecone** | Knowledge Base (Returns Policy, Sizing Guides). | Free Tier |

## 3. Workflow (The "CS Automator")

### Phase 1: Classification
*   **Trigger:** New Ticket in Gorgias.
*   **AI Action:** Classify intent.
    *   `WISMO` (Where is my order)
    *   `Returns`
    *   `Product_Question`
    *   `Complaint` (Escalate to Human)

### Phase 2: Execution (The "WISMO" Example)
*   **Intent:** `WISMO`
*   **Action:**
    1.  Extract `email` or `order_id` from ticket body.
    2.  Query Shopify API: `GET /orders?email=...`
    3.  Check `fulfillment_status`.
        *   If `shipped`: Get `tracking_url`.
        *   If `unfulfilled`: Check `created_at`.
*   **Draft Reply:** "Hi [Name], great news! Your order #1234 is on its way. Tracking: [Link]. It should arrive by [Date]."

### Phase 3: Response & Tagging
*   **Action:**
    *   Post internal note: "AI Generated Reply".
    *   **Trust Level 1:** Draft only.
    *   **Trust Level 3:** Send immediately + Close Ticket.
    *   Tag ticket: `automated-resolution`.

## 4. Implementation Plan

### Week 1: Knowledge & Integration
1.  **Ingest:** Scrape the brand's FAQ, Returns Policy, and Shipping Info into Pinecone.
2.  **Connect:** Setup Shopify Admin API read-only access.

### Week 2: Guardrails & Testing
1.  **Tone Match:** Fine-tune the prompt to sound like the brand (Playful vs Luxury).
2.  **Safety:** Ensure it never hallucinates refunds or discounts. "I cannot process refunds directly, but I've flagged this for a manager."

## 5. ROI Calculation

**Scenario:** Fashion Brand ($5M GMV).
*   **Tickets/Month:** 3,000.
*   **WISMO %:** 40% (1,200 tickets).
*   **Cost per Ticket:** $5 (Human Agent).
*   **Automation Savings:** 1,200 * $5 = **$6,000/mo**.

**Cost:** $500/mo.
**ROI:** 12x.
