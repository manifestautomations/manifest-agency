const fs = require('fs');
const path = require('path');

// Simulate enrichment API
async function enrichLead(lead) {
  // Mock response
  const enrichedData = {
    ...lead,
    technographics: ["HubSpot", "React", "AWS"],
    employees: 50,
    location: "San Francisco, CA",
    decision_maker: {
      name: lead.name,
      title: "VP of Sales",
      email: `${lead.name.split(' ')[0].toLowerCase()}@${lead.company.replace(/\s+/g, '').toLowerCase()}.com`
    }
  };
  return enrichedData;
}

async function main() {
    let inputData;
    // Check if piped stdin or file arg
    try {
        if (!process.stdin.isTTY) {
            inputData = fs.readFileSync(0, 'utf-8');
        } else if (process.argv[2]) {
            inputData = fs.readFileSync(process.argv[2], 'utf-8');
        } else {
            // Default to mock data if no input
             inputData = JSON.stringify([{
                "id": "lead_001",
                "name": "Alex Chen",
                "company": "ScaleUp SaaS",
                "domain": "scaleupsaas.com",
                "source": "Octolens",
                "topic": "Looking for AI sales tools"
            }]);
        }
    } catch (e) {
        console.error("Error reading input:", e);
        process.exit(1);
    }

    try {
        const leads = JSON.parse(inputData);
        // Handle single object or array
        const leadArray = Array.isArray(leads) ? leads : [leads];
        const results = [];

        for (const lead of leadArray) {
            const enriched = await enrichLead(lead);
            results.push(enriched);
        }

        console.log(JSON.stringify(results, null, 2));
    } catch (e) {
        console.error("Error parsing JSON:", e);
        process.exit(1);
    }
}

main();
