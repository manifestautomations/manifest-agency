const fs = require('fs');
const path = require('path');

const DRAFTS_DIR = path.join(__dirname, 'drafts');

function preview() {
    if (!fs.existsSync(DRAFTS_DIR)) {
        console.error("No drafts directory found. Run 'node generate-drafts.js' first.");
        return;
    }

    const files = fs.readdirSync(DRAFTS_DIR).filter(f => f.endsWith('.txt'));
    
    console.log(`\n📬 Found ${files.length} Drafts:\n`);
    console.log(`| ${'Agency'.padEnd(25)} | ${'To'.padEnd(30)} | ${'Subject'.padEnd(40)} |`);
    console.log(`|${'-'.repeat(27)}|${'-'.repeat(32)}|${'-'.repeat(42)}|`);

    files.forEach(file => {
        const content = fs.readFileSync(path.join(DRAFTS_DIR, file), 'utf8');
        const lines = content.split('\n');
        
        const toLine = lines.find(l => l.startsWith('To:')) || '';
        const subjectLine = lines.find(l => l.startsWith('Subject:')) || '';
        
        const to = toLine.replace('To:', '').trim();
        const subject = subjectLine.replace('Subject:', '').trim();
        const agency = file.replace('_draft.txt', '').replace(/_/g, ' ');

        console.log(`| ${agency.padEnd(25)} | ${to.substring(0, 28).padEnd(30)} | ${subject.substring(0, 38).padEnd(40)} |`);
    });

    console.log(`\n👉 To send: 'node send-emails.js' (Check .env first!)\n`);
}

preview();
