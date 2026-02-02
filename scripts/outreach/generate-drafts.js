const fs = require('fs');
const path = require('path');

// Move from scripts/outreach -> scripts -> repo_root
const REPO_ROOT = path.resolve(__dirname, '../..');
const TARGET_LIST_PATH = path.join(REPO_ROOT, 'docs', 'target-list.md');
const TEMPLATES_PATH = path.join(REPO_ROOT, 'templates', 'outreach', 'cold-outreach-v1.md');
const OUTPUT_DIR = path.join(__dirname, 'drafts');

if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR);
}

function parseMarkdownTable(markdown, sectionHeader) {
    const lines = markdown.split('\n');
    let inSection = false;
    let tableLines = [];
    
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line.includes(sectionHeader)) {
            inSection = true;
            continue;
        }
        if (inSection && line.startsWith('## ')) {
            break; // Next section
        }
        if (inSection && line.startsWith('|') && !line.includes('---')) {
            tableLines.push(line);
        }
    }

    // Parse header
    if (tableLines.length < 2) return [];
    
    // Skip header row (index 0)
    const dataRows = tableLines.slice(1);
    
    return dataRows.map(row => {
        const cells = row.split('|').map(c => c.trim()).filter(c => c !== '');
        // Layout: | # | Agency | Founder/CEO | Email | LinkedIn | Personalization Hook |
        if (cells.length < 6) return null;
        return {
            id: cells[0],
            agency: cells[1].replace(/\*\*/g, ''),
            founder: cells[2],
            email: cells[3].split(' ')[0], // simple extraction
            linkedin: cells[4],
            hook: cells[5]
        };
    }).filter(x => x);
}

function getTemplate(markdown, templateName) {
    const lines = markdown.split('\n');
    let inTemplate = false;
    let content = [];
    
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.includes(templateName)) {
            inTemplate = true;
            continue;
        }
        if (inTemplate && line.startsWith('## Template')) {
            break;
        }
        if (inTemplate) {
            content.push(line);
        }
    }
    return content.join('\n').trim();
}

function main() {
    console.log(`Reading targets from ${TARGET_LIST_PATH}...`);
    const targetContent = fs.readFileSync(TARGET_LIST_PATH, 'utf8');
    const templateContent = fs.readFileSync(TEMPLATES_PATH, 'utf8');

    const targets = parseMarkdownTable(targetContent, 'Tier 1: High Priority');
    const templateRaw = getTemplate(templateContent, 'Template 1: First Touch');

    // Extract body and subject from template
    // Template format in markdown has **Subject lines...** and **Body:**
    
    const bodyStart = templateRaw.indexOf('**Body:**');
    let bodyTemplate = templateRaw.substring(bodyStart + 9).trim();
    
    // Clean up "Hi [FIRST NAME]," -> "Hi [FIRST NAME],"
    
    console.log(`Found ${targets.length} targets.`);

    targets.forEach(target => {
        let emailBody = bodyTemplate;
        const firstName = target.founder.split(' ')[0];
        
        emailBody = emailBody.replace(/\[FIRST NAME\]/g, firstName);
        emailBody = emailBody.replace(/\[AGENCY NAME\]/g, target.agency);
        emailBody = emailBody.replace(/\[PERSONALIZATION_HOOK\]/g, target.hook);
        emailBody = emailBody.replace(/\[CALENDLY LINK\]/g, 'https://calendly.com/manifest-automations/30min'); // Hardcoded based on doc
        
        const filename = `${target.agency.replace(/\s+/g, '_')}_draft.txt`;
        const filepath = path.join(OUTPUT_DIR, filename);
        
        const fullContent = `To: ${target.email}\nSubject: Quick question about ${target.agency}'s reporting\n\n${emailBody}`;
        
        fs.writeFileSync(filepath, fullContent);
        console.log(`Generated draft: ${filepath}`);
    });
}

main();
