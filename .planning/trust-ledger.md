# 🔐 Trust Ledger (Earned Autonomy)

This file tracks the trust levels of AI Agents operating within the Manifest Automations ecosystem.
All agents start at **Level 0** and must earn promotion through verified successful actions.

## 🎖️ Trust Levels

| Level | Name | Permissions | Criteria |
|:---:|:---|:---|:---|
| **0** | **Untrusted (Intern)** | Read-Only. Must propose changes via PR. | Default state. |
| **1** | **Contributor** | Can modify non-critical files (docs, tests). | 5+ merged PRs. 100% test pass rate. |
| **2** | **Maintainer** | Can merge to `main`. Can deploy to staging. | 20+ merged PRs. No critical bugs caused. |
| **3** | **Architect** | Can change infrastructure/auth. Can deploy to prod. | 50+ merged PRs. Human sign-off required. |
| **4** | **Partner** | Full Admin Access. | Reserved for specific proven agents. |

---

## 📒 Ledger

| Date | Agent ID | Action | New Level | Reason / Proof | Hash (Commit/PR) |
|:---|:---|:---|:---:|:---|:---|
| 2026-01-27 | `clawdbot-primary` | **INIT** | **0** | Initial Bootstrap | `N/A` |
| 2026-01-27 | `clawdbot-primary` | **PROMOTION** | **1** | Scaffolding completed, docs written, tests passing (CI) | `(Self-Verified)` |

---

## 🛑 Blocklist (Revoked Trust)

| Date | Agent ID | Reason | Incident Log |
|:---|:---|:---|:---|
| | | | |
