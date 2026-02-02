# Deployment Checklist (Post-Merge)

**Goal:** Ensure a smooth launch of the Agency Website + Growth Stack immediately after PR #4 and PR #5 are merged.

## 1. Vercel Configuration (Production)
- [ ] **Connect Repo:** Link `manifest-agency-repo/projects/agency-website` to Vercel.
- [ ] **Environment Variables:**
    - `NEXT_PUBLIC_SITE_URL`: `https://manifest.agency`
    - `GTM_ID`: (Google Tag Manager ID)
    - `POSTHOG_KEY`: (Analytics)
- [ ] **Build Settings:**
    - Framework: `Next.js`
    - Root Directory: `projects/agency-website`
    - Build Command: `npm run build`

## 2. pSEO Verification
- [ ] **Build Logs:** Check Vercel logs for `Generating static pages (75/75)`.
- [ ] **Sitemap:** Verify `https://manifest.agency/sitemap.xml` contains the new dynamic routes (e.g., `/services/dental/chicago`).
- [ ] **Canonical Tags:** Ensure dynamic pages have self-referencing canonicals to prevent duplicate content flags.

## 3. Integration Testing
- [ ] **ROI Calculator:**
    - Submit a test lead.
    - Verify console log (or webhook if connected).
- [ ] **Booking Page:**
    - Click "Book a Call".
    - Verify Calendly embed loads correctly.
- [ ] **Contact Forms:**
    - Verify email validation logic.

## 4. Sales Automation (Local)
- [ ] **Pull Latest Main:** `git checkout main && git pull`.
- [ ] **Install Deps:** `cd scripts/outreach && npm install`.
- [ ] **Env Setup:** `cp .env.example .env` and fill in Gmail SMTP details.
- [ ] **Test Send:** `npm run send -- --dry-run` to verify draft generation without sending.

## 5. Marketing Launch
- [ ] **Social:** Post the "Death of the Retainer" thread on X.
- [ ] **LinkedIn:** Update Company Page with new URL.
- [ ] **Directory:** Submit to CSS galleries / Awwwards (optional).
