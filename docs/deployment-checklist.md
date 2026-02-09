# Deployment Checklist v2.0 (AI Staffing Pivot)

**Goal:** Ensure a smooth launch of the Agency Website + AI Staffing Products immediately after PR #6 is merged.

## 1. Vercel Configuration (Production)
- [ ] **Connect Repo:** Link `manifest-agency-repo/projects/agency-website` to Vercel.
- [ ] **Environment Variables:**
    - `NEXT_PUBLIC_SITE_URL`: `https://manifest.agency`
    - `NEXT_PUBLIC_VAPI_PUBLIC_KEY`: (From Vapi Dashboard)
    - `CLAWDBOT_GATEWAY_TOKEN`: (For Headless Agent API - Server Side Only)
    - `CLAWDBOT_GATEWAY_URL`: (Your Gateway URL, e.g., `https://gateway.manifest.agency`)
    - `GTM_ID`: (Google Tag Manager ID)
    - `POSTHOG_KEY`: (Analytics)
- [ ] **Build Settings:**
    - Framework: `Next.js`
    - Root Directory: `projects/agency-website`
    - Build Command: `npm run build`

## 2. pSEO Verification
- [ ] **Build Logs:** Check Vercel logs for `Generating static pages (100+/100+)` (Includes new AI Vertical pages).
- [ ] **Sitemap:** Verify `https://manifest.agency/sitemap.xml` contains the new dynamic routes (e.g., `/services/recruiting/san-francisco`).
- [ ] **Canonical Tags:** Ensure dynamic pages have self-referencing canonicals.

## 3. Product Integration Testing
- [ ] **AI Recruiter Demo:**
    - Visit `/recruiter/new-job`.
    - Click "Start Call" (Mock or Real Vapi).
    - Verify microphone permissions request.
- [ ] **Headless Agent API:**
    - POST to `/api/agents/invoke` with a test task.
    - Verify 200 OK response.
- [ ] **ROI Calculator:**
    - Submit a test lead.
    - Verify console log (or webhook if connected).

## 4. Sales Automation (Local)
- [ ] **Pull Latest Main:** `git checkout main && git pull`.
- [ ] **Install Deps:** `cd scripts/outreach && npm install`.
- [ ] **Env Setup:** `cp .env.example .env` and fill in Gmail SMTP details.
- [ ] **Test Send:** `npm run send -- --dry-run` to verify draft generation without sending.

## 5. Marketing Launch
- [ ] **Social:** Post the "Stop Hiring Humans" thread on X.
- [ ] **LinkedIn:** Update Company Page with new URL.
- [ ] **Directory:** Submit to AI Directories (There's An AI For That, etc.).
