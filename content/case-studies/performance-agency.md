---
title: "Automated Reporting for NY Performance Agency"
client: "AdVantage Media"
industry: "Marketing Agency"
service: "Automated Reporting Pipeline"
results:
  - "70% Reduction in Analyst Time"
  - "10x ROI in First Year"
  - "Monthly Reporting Time: 4 Days → 0 Days"
slug: "performance-agency"
---

# The Problem

AdVantage Media (25 employees) manages $2M/mo in ad spend. Their "Reporting Week" was legendary—and hated.
- **The Grind:** 4 Analysts spent the first week of every month copying data from Facebook Ads, Google Ads, and TikTok into Excel.
- **The Cost:** 160 analyst hours per month (approx $8,000/mo) wasted on copy-pasting.
- **The Risk:** Burnout was high. Data accuracy was low.

# The Solution

We built a custom ETL pipeline:
- **Pipeline:** Airbyte (hosted) to extract data daily.
- **Warehouse:** Google BigQuery to store the raw data history.
- **Presentation:** Looker Studio dashboards that query BigQuery directly.

# The Outcome

- **Zero-Touch Reporting:** Client dashboards update automatically every morning at 6 AM.
- **Analyst Freedom:** The team reclaimed 1 week per month to focus on strategy and optimization.
- **Client Trust:** Clients stopped asking "Why doesn't this match Facebook?" because the data is identical.
