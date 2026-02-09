// Recruiting Knowledge Graph Schema (Neo4j Cypher)
// Version: 1.0
// Based on: docs/recruiting/graph-schema.md

// ==========================================
// 1. Constraints & Indexes
// ==========================================

// Candidate Constraints
CREATE CONSTRAINT candidate_id IF NOT EXISTS FOR (c:Candidate) REQUIRE c.id IS UNIQUE;
CREATE INDEX candidate_name_idx IF NOT EXISTS FOR (c:Candidate) ON (c.name);

// Company Constraints
CREATE CONSTRAINT company_name IF NOT EXISTS FOR (c:Company) REQUIRE c.name IS UNIQUE;

// Skill Constraints
CREATE CONSTRAINT skill_name IF NOT EXISTS FOR (s:Skill) REQUIRE s.name IS UNIQUE;

// JobRole Constraints
CREATE CONSTRAINT jobrole_title IF NOT EXISTS FOR (j:JobRole) REQUIRE j.title IS UNIQUE;

// Industry Constraints
CREATE CONSTRAINT industry_name IF NOT EXISTS FOR (i:Industry) REQUIRE i.name IS UNIQUE;

// ==========================================
// 2. Node Structures (Reference)
// ==========================================
// Note: Neo4j is schemaless, but we enforce these properties in the application layer.

// (:Candidate {
//   id: UUID,
//   name: String,
//   email: String,
//   linkedin_url: String,
//   total_yoe: Float,
//   summary_embedding: List<Float>  // Vector embedding for semantic search
// })

// (:Company {
//   name: String,
//   tier: String,      // "Tier 1", "Startup", "Enterprise", "Agency"
//   stage: String,     // "Seed", "Series A", "Public"
//   description: String
// })

// (:Skill {
//   name: String,      // "React", "Python"
//   category: String   // "Frontend", "Backend"
// })

// ==========================================
// 3. Relationships (Edges)
// ==========================================

// WORKED_AT: Tenure and Role
// (:Candidate)-[:WORKED_AT {
//   title: String,
//   start_date: Date,
//   end_date: Date,
//   is_current: Boolean,
//   description: String
// }]->(:Company)

// HAS_SKILL: Proficiency
// (:Candidate)-[:HAS_SKILL {
//   proficiency: Integer, // 1-5
//   verified: Boolean,    // True if verified by Vapi interview
//   last_used: Date
// }]->(:Skill)

// IN_INDUSTRY: Domain Knowledge
// (:Company)-[:IN_INDUSTRY]->(:Industry)

// ==========================================
// 4. Sample Seed Data (For Testing)
// ==========================================

// Create Industries
MERGE (fintech:Industry {name: "Fintech"})
MERGE (health:Industry {name: "Healthcare"})
MERGE (ecommerce:Industry {name: "E-commerce"})

// Create Companies
MERGE (stripe:Company {name: "Stripe", tier: "Tier 1", stage: "Public"})
MERGE (plaid:Company {name: "Plaid", tier: "Tier 1", stage: "Public"})
MERGE (unknown_agency:Company {name: "DevShop LLC", tier: "Agency", stage: "Bootstrap"})

// Link Companies to Industries
MERGE (stripe)-[:IN_INDUSTRY]->(fintech)
MERGE (plaid)-[:IN_INDUSTRY]->(fintech)

// Create Skills
MERGE (react:Skill {name: "React", category: "Frontend"})
MERGE (node:Skill {name: "Node.js", category: "Backend"})
MERGE (neo4j:Skill {name: "Neo4j", category: "Database"})

// Create Candidate (John Doe)
CREATE (john:Candidate {
  id: "uuid-1234",
  name: "John Doe",
  total_yoe: 5.5
})

// Create Relationships
CREATE (john)-[:WORKED_AT {title: "Senior Engineer", start_date: date("2022-01-01"), is_current: true}]->(stripe)
CREATE (john)-[:HAS_SKILL {proficiency: 5, verified: true}]->(react)
CREATE (john)-[:HAS_SKILL {proficiency: 4, verified: true}]->(node)

// ==========================================
// 5. Reasoning Query Examples
// ==========================================

// "Find candidates who worked at Tier 1 Fintech companies and know React"
// MATCH (c:Candidate)-[:WORKED_AT]->(comp:Company)
// WHERE comp.tier = "Tier 1" AND (comp)-[:IN_INDUSTRY]->(:Industry {name: "Fintech"})
// MATCH (c)-[:HAS_SKILL]->(s:Skill {name: "React"})
// RETURN c.name, comp.name, s.proficiency
