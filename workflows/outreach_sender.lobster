name: outreach_sender
description: "Send personalized cold emails with human approval per batch"
args:
  batchSize:
    type: number
    description: "Number of emails to send in this batch (default: 5)"
    default: 5
steps:
  - id: check_config
    command: test -f scripts/outreach/.env || echo "MISSING_ENV"
    cwd: manifest-agency-repo
    description: "Verify .env exists"

  - id: validate_env
    command: echo "Error: .env missing. Create it from .env.example first."
    condition: ${{steps.check_config.stdout}} == "MISSING_ENV"
    halt: true

  - id: list_drafts
    command: ls -1 scripts/outreach/drafts/*_draft.txt | head -n ${{args.batchSize}}
    cwd: manifest-agency-repo
    description: "Select the next batch of drafts"

  - id: preview_batch
    description: "I will send emails to the following recipients. Proceed?"
    approval: required
    stdin: ${{steps.list_drafts.stdout}}

  - id: send_emails
    command: node scripts/outreach/send-emails.js
    cwd: manifest-agency-repo
    condition: ${{steps.preview_batch.approved}}
    env:
      BATCH_LIMIT: ${{args.batchSize}}
