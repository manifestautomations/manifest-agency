# Programmatic SEO (pSEO) Implementation Plan

**Status:** Draft / Proposed
**Date:** 2026-02-01
**Goal:** Generate 1,000+ targeted landing pages to capture long-tail search traffic for agency services.

## The Strategy

Instead of manually writing pages for every niche, we use **Next.js Dynamic Routes** (`[industry]/[location]/page.tsx`) to generate them from a data file.

**Target Keyword Pattern:**
`"AI Automation for [Industry] in [City]"`
*Example: "AI Automation for Dental Agencies in Chicago"*

## Architecture

### 1. Data Source (`content/pseo-data.json`)
We will maintain a robust JSON dataset containing:
- **Industries:** Dental, Real Estate, Legal, E-commerce, Recruiting.
- **Locations:** Top 50 US Cities (tier 1 & 2).
- **Use Cases:** Specific pain points per industry (e.g., "Patient Scheduling" for Dental).

```json
{
  "industries": [
    {
      "slug": "dental",
      "name": "Dental Clinics",
      "pain_point": "missed patient calls",
      "solution": "AI Voice Receptionist"
    }
  ],
  "locations": [
    { "slug": "chicago", "name": "Chicago", "state": "IL" },
    { "slug": "austin", "name": "Austin", "state": "TX" }
  ]
}
```

### 2. The Template (`app/services/[industry]/[location]/page.tsx`)
A single, highly optimized Next.js page component that accepts params.

**Key Components:**
- **Dynamic H1:** "Stop Losing [Pain Point] in [City]: AI Automation for [Industry]"
- **Local SEO:** Schema markup identifying the service area as [City].
- **Industry Specifics:** Swaps out case study references based on industry slug.

### 3. Static Site Generation (generateStaticParams)
We will use `generateStaticParams` to build these pages at build time (SSG), ensuring:
- Blazing fast load times (critical for SEO).
- Perfect indexability by Google.
- Zero database hits on request.

## Implementation Steps

1. **Data Collection:** Build the `pseo-data.json` file. (Start with 5 industries x 10 cities = 50 pages).
2. **Template Design:** Create the generic page layout in Next.js.
3. **Internal Linking:** Create a `/locations` directory page to help crawlers find these pages.
4. **Sitemap:** Update `app/sitemap.ts` to include these dynamic URLs.

## Risks & Mitigation
- **Duplicate Content:** We must ensure the *solutions* section varies enough per industry.
- **Cannibalization:** Ensure these don't compete with our main `/services` page. (They won't, they are too long-tail).

## Next Actions
- [ ] Wait for PR #4 merge (Base site).
- [ ] Create `pseo-data.json`.
- [ ] Scaffold the dynamic route.
