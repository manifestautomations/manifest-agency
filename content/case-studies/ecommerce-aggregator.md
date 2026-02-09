---
title: "Global Dashboard for E-Commerce Aggregator"
client: "ScaleUp Brands"
industry: "E-Commerce"
service: "Data Warehouse & dbt"
results:
  - "Data lag reduced from 24h to 5min"
  - "0% Reporting Errors"
  - "Real-time Currency Standardization"
slug: "ecommerce-aggregator"
---

# The Problem

ScaleUp Brands acquires and grows e-commerce shops. With 12 brands across 4 countries, their data was a mess.
- **Currencies:** USD, EUR, GBP, CAD.
- **Platforms:** Shopify, Amazon, WooCommerce.
- **Process:** A CFO and 2 analysts spent 3 hours every morning manually updating a "Global View" spreadsheet.
- **Impact:** Decision-making was always 24 hours behind. Currency fluctuations were manually calculated (often wrongly).

# The Solution

We deployed a Modern Data Stack:
- **Ingestion:** Fivetran to pull data from all 12 storefronts into Snowflake.
- **Transformation:** dbt (Data Build Tool) to normalize all currencies to USD using real-time exchange rates.
- **Visualization:** A PowerBI dashboard that reads directly from Snowflake.

# The Outcome

- **Real-Time Visibility:** The CEO checks sales performance across all brands on their phone, updated every 15 minutes.
- **Error Elimination:** No more broken formulas or bad exchange rates.
- **Strategic Focus:** The CFO now spends time on acquisition strategy, not spreadsheet maintenance.
