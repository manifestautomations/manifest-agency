name: client_onboarding
description: "Level 2 Autonomous Onboarding Workflow with Human Gates"
args:
  clientName:
    type: string
    description: "Full Client Name (e.g. 'Acme Corp')"
  slug:
    type: string
    description: "Kebab-case slug (e.g. 'acme-corp')"
steps:
  - id: validate_input
    command: echo "Starting onboarding for ${{args.clientName}} (${{args.slug}})..."

  - id: scaffold
    command: ./scripts/scaffold-project.sh "${{args.clientName}}" "${{args.slug}}"
    cwd: manifest-agency-repo
    description: "Generates directory structure, README, and Trust Ledger"

  - id: verify_scaffold
    command: ls -F projects/${{args.slug}}/
    cwd: manifest-agency-repo
    description: "List generated files for review"

  - id: approve_structure
    description: "Review the scaffolded files. Proceed to commit?"
    approval: required
    stdin: ${{steps.verify_scaffold.stdout}}

  - id: git_commit
    command: |
      git add projects/${{args.slug}}
      git commit -m "feat: onboard client ${{args.clientName}}"
    cwd: manifest-agency-repo
    condition: ${{steps.approve_structure.approved}}

  - id: approve_push
    description: "Ready to push to GitHub and create remote resources?"
    approval: required

  - id: git_push
    command: git push origin main
    cwd: manifest-agency-repo
    condition: ${{steps.approve_push.approved}}

  - id: create_channels
    command: echo "TODO: Create Discord channels for ${{args.slug}}"
    condition: ${{steps.approve_push.approved}}
