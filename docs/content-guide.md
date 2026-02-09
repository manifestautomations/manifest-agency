# Content Management Guide

**Goal:** How to add new Blog Posts, Case Studies, Testimonials, and pSEO Pages to the Agency Website.

## 1. Blog Posts
**Location:** `content/blog/*.md`

### Frontmatter Schema
```yaml
---
title: "Title of the Post"
date: "YYYY-MM-DD"
author: "Author Name"
slug: "url-friendly-slug"
tags: ["Tag1", "Tag2"]
status: "Ready" # or "Draft"
description: "SEO Meta Description (150-160 chars)"
excerpt: "Short summary for the blog index card."
---
```

### Tips
- Use standard Markdown (`##`, `**bold**`, `[link](url)`).
- Images should be placed in `public/images/blog/` and referenced as `/images/blog/filename.jpg`.

---

## 2. Case Studies
**Location:** `content/case-studies/*.md`

### Frontmatter Schema
```yaml
---
title: "Headline of the Case Study"
client: "Client Name"
industry: "Industry Name"
service: "Service Provided (e.g., Data Warehouse)"
results:
  - "Key Result 1 (e.g., 50% Cost Reduction)"
  - "Key Result 2"
  - "Key Result 3"
slug: "url-friendly-slug"
---
```

### Structure
Use these headers for consistency:
1. `# The Problem`
2. `# The Solution`
3. `# The Outcome`

---

## 3. Testimonials
**Location:** `content/testimonials/*.md`

### Frontmatter Schema
```yaml
---
name: "Client Name"
role: "Job Title, Company"
quote: "The actual testimonial text goes here. Keep it punchy."
rating: 5
slug: "client-name-slug"
---
```
*Note: The body of the file is currently unused, but you can leave it empty.*

---

## 4. Programmatic SEO (pSEO)
**Location:** `content/pseo-data.json`

This JSON file drives the generation of thousands of landing pages (e.g., `/ai-automation-agency/dental/new-york`).

### Structure
- **Industries:** Define the vertical, pain points, and specific stats.
- **Locations:** Define the cities you want to target.

### Adding an Industry
```json
{
  "slug": "recruiting",
  "name": "Recruiting Firms",
  "pain_point": "screening 1000s of resumes",
  "solution": "AI Candidate Screener",
  "value_prop": "Interview every applicant in 5 minutes.",
  "stats": [
    { "label": "Time per Resume", "value": "6s", "source": "Ladders" },
    { "label": "Placement Fee", "value": "20%", "source": "Industry Avg" },
    { "label": "Response Time", "value": "Instant", "source": "Manifest AI" }
  ]
}
```

### Adding a Location
```json
{ "slug": "austin", "name": "Austin", "state": "TX" }
```
*Note: Adding 1 industry with 50 locations creates 50 new pages instantly.*
