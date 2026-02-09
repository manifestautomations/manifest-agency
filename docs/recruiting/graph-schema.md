# Knowledge Graph Schema: Candidate Data Extraction

## Overview
This document defines the schema and extraction strategy for converting unstructured candidate documents (Resumes, CVs, Transcripts) into a structured Knowledge Graph.

We utilize **DeepSeek R1** for its superior reasoning capabilities to perform "Schema-Aligned Parsing". This approach goes beyond simple keyword extraction by inferring implicit skills, role seniority, and domain expertise based on context.

## Extraction Pipeline
1.  **Input**: Raw text from PDF/Word documents (Resume/Transcript).
2.  **Model**: DeepSeek R1 (reasoning-optimized).
3.  **Strategy**: Chain-of-Thought (CoT) prompting with strict JSON schema enforcement.
4.  **Output**: Structured JSON object matching the `CandidateProfile` schema.
5.  **Storage**: Data is normalized and ingested into a Graph Database (Neo4j or Supabase Graph).

## JSON Schema Structure

The extraction target is a `CandidateProfile` object containing the following entities:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "candidate_info": {
      "type": "object",
      "properties": {
        "name": { "type": "string" },
        "email": { "type": "string" },
        "phone": { "type": "string" },
        "linkedin_url": { "type": "string" },
        "portfolio_url": { "type": "string" },
        "summary": { "type": "string" },
        "total_years_experience": { "type": "number" }
      }
    },
    "work_experience": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "company": { "type": "string" },
          "title": { "type": "string" },
          "start_date": { "type": "string", "format": "YYYY-MM" },
          "end_date": { "type": "string", "format": "YYYY-MM" },
          "is_current": { "type": "boolean" },
          "description": { "type": "string" },
          "technologies_used": { "type": "array", "items": { "type": "string" } },
          "achievements": { "type": "array", "items": { "type": "string" } }
        }
      }
    },
    "education": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "institution": { "type": "string" },
          "degree": { "type": "string" },
          "field_of_study": { "type": "string" },
          "start_year": { "type": "string" },
          "end_year": { "type": "string" }
        }
      }
    },
    "skills": {
      "type": "object",
      "properties": {
        "explicit": { "type": "array", "items": { "type": "string" }, "description": "Skills explicitly mentioned in the text" },
        "inferred": { "type": "array", "items": { "type": "string" }, "description": "Skills inferred via reasoning (e.g., React -> Frontend)" }
      }
    },
    "projects": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "description": { "type": "string" },
          "technologies": { "type": "array", "items": { "type": "string" } },
          "url": { "type": "string" }
        }
      }
    }
  }
}
```

## DeepSeek R1: Reasoning & Inference

A key advantage of using DeepSeek R1 is its ability to perform "Reasoning" to populate the `skills.inferred` field and normalize data.

### 1. Inferring Implicit Skills
R1 analyzes the context of work experience to deduce skills that aren't explicitly listed.

*   **Example 1:**
    *   *Input:* "Built a responsive dashboard using Shadcn UI and managed state with Zustand."
    *   *Explicit:* "Shadcn UI", "Zustand"
    *   *Reasoning:* "Zustand is a state management library for React. Shadcn UI is a React component library. Therefore, the candidate knows **React** and **Frontend Development**."
    *   *Inferred:* "React", "Frontend Development"

*   **Example 2:**
    *   *Input:* "Deployed microservices to ECS and configured ALBs via Terraform."
    *   *Explicit:* "ECS", "ALB", "Terraform"
    *   *Reasoning:* "ECS and ALB are AWS services. Terraform is Infrastructure as Code. This workflow implies **AWS**, **Cloud Engineering**, and **DevOps** practices."
    *   *Inferred:* "AWS", "DevOps", "CI/CD"

### 2. Normalizing Roles & Seniority
R1 standardizes job titles to help with matching.

*   *Input:* "Member of Technical Staff (Level 4)"
*   *Inferred Normalized Title:* "Senior Software Engineer"

### 3. Entity Resolution
R1 disambiguates company names and institutions.

*   *Input:* "CMU" -> *Output:* "Carnegie Mellon University"
*   *Input:* "Meta" (2015) -> *Output:* "Facebook" (Context aware)

## Graph Database Mapping (Neo4j)

The extracted JSON is mapped to Graph nodes and relationships:

*   **Nodes**: `Candidate`, `Skill`, `Company`, `Institution`, `Project`
*   **Relationships**:
    *   `(:Candidate)-[:HAS_SKILL {type: "explicit"|"inferred"}]->(:Skill)`
    *   `(:Candidate)-[:WORKED_AT {role: "...", duration: "..."}]->(:Company)`
    *   `(:Candidate)-[:EDUCATED_AT]->(:Institution)`
    *   `(:Project)-[:USES_TECH]->(:Skill)`

This graph structure enables complex queries like:
> "Find candidates who have inferred experience in 'Fintech' based on their work history at companies like Stripe or Plaid, even if 'Fintech' isn't on their resume."
