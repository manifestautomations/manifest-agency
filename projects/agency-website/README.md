# Manifest Agency Website (MVP)

The public face of Manifest Agency, built with Next.js 16 and Tailwind CSS.

## Features

- **Dynamic Blog:** Markdown-based blog engine (`content/blog/*.md`).
- **Dynamic Case Studies:** Markdown-based case studies (`content/case-studies/*.md`).
- **pSEO Engine:** Generates thousands of landing pages from `content/pseo-data.json`.
- **Lead Capture:** Integrated with Leadsie and Octolens via Webhooks.
- **Voice AI Demo:** Vapi.ai integration demo page.

## Content Management

### Adding a Blog Post
1. Create a new markdown file in `../../content/blog/`.
2. Add frontmatter:
   ```yaml
   ---
   title: "My New Post"
   date: "2026-02-04"
   author: "Tyler Smith"
   slug: "my-new-post"
   description: "Short SEO description."
   ---
   ```
3. Commit and push.

### Adding a Case Study
1. Create a new markdown file in `../../content/case-studies/`.
2. Add frontmatter:
   ```yaml
   ---
   title: "Saved 20 Hours/Week"
   client: "Acme Corp"
   industry: "Dental"
   service: "Voice AI"
   results:
     - "0% Missed Calls"
     - "$15k Revenue"
   slug: "acme-corp"
   ---
   ```

### Updating pSEO Pages
1. Edit `../../content/pseo-data.json`.
2. Add new `industries` or `locations`.
3. The site automatically generates `services/[industry]/[location]` pages at build time.

## Development

```bash
cd projects/agency-website
npm install
npm run dev
```

## Deployment

Deploys automatically to Vercel on push to `main`.
Environment variables required:
- `OCTOLENS_WEBHOOK_SECRET`
- `VAPI_WEBHOOK_SECRET`
