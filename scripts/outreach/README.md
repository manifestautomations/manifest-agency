# Outreach Automation Scripts

This folder contains scripts to automate cold outreach to prospective agency clients.

## Setup

1. **Install Dependencies:**
   ```bash
   cd scripts/outreach
   npm install
   ```

2. **Configure Environment:**
   Create a `.env` file in this directory:
   ```bash
   cp .env.example .env
   ```
   
   Fill in your SMTP details (e.g., Gmail, Outlook, or SMTP provider like SendGrid/Postmark).

   **Example `.env`:**
   ```env
   # SMTP Configuration (Required for sending)
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_SECURE=false
   SMTP_USER=your-email@gmail.com
   SMTP_PASS=your-app-password
   SMTP_FROM="Tyler Smith <tyler@manifest.agency>"

   # Safety Switch (Set to 'false' to actually send)
   DRY_RUN=true
   ```

## Workflow

### 1. Generate Drafts
Reads from `docs/target-list.md` and `templates/outreach/cold-outreach-voice.md` to create personalized text files.

```bash
node generate-drafts.js
```
*Output: `drafts/Agency_Name_draft.txt`*

### 2. Review Drafts
Check the `drafts/` folder. You can manually edit any text file to personalize it further. The sender script uses the content of these files exactly as they are.

**Quick Preview:**
To see a summary table of all generated drafts:
```bash
node preview-drafts.js
```

### 3. Send Emails
Reads all files in `drafts/`, parses them, and sends them via SMTP.

**Dry Run (Test Mode):**
```bash
node send-emails.js
```
*Prints what would be sent to the console.*

**Live Mode:**
1. Edit `.env` and set `DRY_RUN=false`.
2. Run:
   ```bash
   node send-emails.js
   ```
   *Sends emails with a 5-15s random delay between each.*
   *Moves sent drafts to `sent/` folder.*

## Notes
- The parser removes any text after `---` at the bottom of the draft (used for internal notes).
- Ensure your SMTP provider allows "Less Secure Apps" or use an App Password (recommended for Gmail).
