# Archived Skills

## orchestrate-v1.md

**Archived:** 2026-01-31
**Reason:** Migration to hybrid agents.md + skills architecture

The original orchestrate.md skill was comprehensive but followed the skills-only pattern.
Vercel research showed 56% non-invocation rate for skills.

**Migration:**
- Core orchestration behavior moved to `.gemini/agents.md` (always loaded)
- Explicit commands split into individual skills:
  - status/ - Dashboard and aggregate metrics
  - briefing/ - Daily portfolio briefing
  - approve/ - Approval workflow
  - dispatch/ - Worker dispatch

See Phase 12 documentation for rationale.

**Research source:** [Vercel - AGENTS.md outperforms skills in agent evals](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals)

**Key finding:** In 56% of eval cases, skills were never invoked. AGENTS.md achieved 100% pass rate vs 53% for skills, a 47 percentage point improvement.

**Hybrid approach benefits:**
- Core context always available (no invocation decision needed)
- Explicit commands still user-triggerable via `/status`, `/briefing`, etc.
- 80% size reduction maintains 100% pass rate (retrieval reasoning pattern)

---

*Archive created: 2026-01-31*
*Phase: 12-anti-gravity-integration*
