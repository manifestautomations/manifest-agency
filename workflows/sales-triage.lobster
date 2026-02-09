# Sales Triage Workflow
# Purpose: Process raw leads from Octolens, enrich them, and draft outreach.
# Status: Draft

name: sales-triage
description: Process inbound leads from social listening, enrich, and draft outreach.

steps:
  # 1. Fetch recent leads from the buffer (simulated for now)
  - id: fetch_leads
    command: cat data/leads-buffer.json
    
  # 2. Enrich the lead using Apollo (simulated call)
  # In production: clawd tool call apollo enrich --domain $fetch_leads.domain
  - id: enrich_lead
    command: node scripts/sales/enrich-leads.js
    stdin: ${{ fetch_leads.stdout }}

  # 3. Generate Draft (LLM Step)
  # Uses the enrichment data to write a personalized message
  - id: generate_draft
    command: clawd agent --task "Write a cold DM to ${{ enrich_lead.stdout[0].name }} mentioning their post about ${{ fetch_leads.stdout[0].topic }} and referencing their use of ${{ enrich_lead.stdout[0].technographics[0] }}."

  # 4. Human Approval Gate
  # STOP here and wait for Tyler/Rich to say "yes"
  - id: approval
    command: echo "Draft ready for review: ${{ generate_draft.stdout }}"
    approval: required

  # 5. Send (only runs if approved)
  - id: send_message
    command: echo "Sending message..." # Placeholder for actual sending logic
    condition: ${{ approval.approved }}
