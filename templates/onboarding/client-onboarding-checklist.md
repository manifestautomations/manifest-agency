# 🚀 Client Onboarding Checklist

**Client:** [Client Name]
**Start Date:** [YYYY-MM-DD]
**Account Owner:** [Name]

---

## Phase 1: The Handshake (Day 0-2)
*Goal: Get legal and money sorted.*

- [ ] **Contract Signed**
  - [ ] SOW signed by both parties.
  - [ ] Counter-signed copy saved to Drive/Dropbox.
- [ ] **Deposit Received**
  - [ ] Invoice #001 sent (via QuickBooks/Stripe).
  - [ ] Payment confirmed.
- [ ] **Internal Setup**
  - [ ] Project added to `active-projects.md`.
  - [ ] Trust Ledger initialized (if using AI agents).

## Phase 2: Technical Setup (Day 3)
*Goal: Create the digital workspace.*

- [ ] **Communication**
  - [ ] Slack/Discord channel created (`#client-name`).
  - [ ] Client stakeholders invited.
  - [ ] Welcome message sent (use `templates/outreach/welcome-email.md`).
- [ ] **Infrastructure**
  - [ ] Run Scaffolding Script: `./scripts/scaffold-project.sh "Client Name" "client-slug"`.
  - [ ] GitHub Repository created.
  - [ ] CI/CD pipeline enabled.
- [ ] **Access Request**
  - [ ] Request access to Client's:
    - [ ] AWS/GCP/Azure
    - [ ] GitHub/GitLab
    - [ ] Analytics (GA4, Mixpanel)
    - [ ] CMS/Database

## Phase 3: Kickoff (Day 4-5)
*Goal: Align on the first sprint.*

- [ ] **Kickoff Call**
  - [ ] Scheduled (30-45 min).
  - [ ] Agenda sent:
    1. Team Intros
    2. Tool Access Check
    3. Sprint 1 Goals
    4. Communication Norms
- [ ] **Sprint 1 Planning**
  - [ ] Brief created in `.planning/BRIEF.md`.
  - [ ] First set of issues created in GitHub.

---

## 🤖 AI Agent Delegation
*Tasks the AI can handle.*

- [ ] Run `scaffold-project.sh`.
- [ ] Generate "Welcome" email draft.
- [ ] Monitor GitHub for "Access Granted" notifications.
