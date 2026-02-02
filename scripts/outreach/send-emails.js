require('dotenv').config();
const fs = require('fs');
const path = require('path');
const nodemailer = require('nodemailer');

// Configuration
const DRAFTS_DIR = path.join(__dirname, 'drafts');
const SENT_DIR = path.join(__dirname, 'sent');
const DRY_RUN = process.env.DRY_RUN !== 'false'; // Default to true for safety

// Create sent directory if it doesn't exist
if (!fs.existsSync(SENT_DIR)) {
    fs.mkdirSync(SENT_DIR);
}

// SMTP Transport
const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: process.env.SMTP_PORT,
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
    },
});

function parseDraft(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    
    let to = '';
    let subject = '';
    let bodyStartIndex = 0;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.startsWith('To: ')) to = line.substring(4).trim();
        else if (line.startsWith('Subject: ')) subject = line.substring(9).trim();
        else if (line.trim() === '') {
            bodyStartIndex = i + 1;
            break;
        }
    }

    // Extract body, removing internal notes if present
    const rawBody = lines.slice(bodyStartIndex).join('\n').trim();
    const body = rawBody.split('\n---\nInternal Note:')[0].trim();

    return { to, subject, body };
}

async function main() {
    console.log(`🚀 Outreach Sender Starting...`);
    console.log(`Mode: ${DRY_RUN ? '🛑 DRY RUN (No emails will be sent)' : '✅ LIVE (Sending emails)'}`);

    if (!DRY_RUN && (!process.env.SMTP_HOST || !process.env.SMTP_USER)) {
        console.error('❌ Error: Missing SMTP configuration in .env');
        process.exit(1);
    }

    const files = fs.readdirSync(DRAFTS_DIR).filter(f => f.endsWith('_draft.txt'));
    
    if (files.length === 0) {
        console.log('No drafts found.');
        return;
    }

    console.log(`Found ${files.length} drafts.`);

    for (const file of files) {
        const filePath = path.join(DRAFTS_DIR, file);
        const { to, subject, body } = parseDraft(filePath);

        console.log(`\n📄 Processing: ${file}`);
        console.log(`   To: ${to}`);
        console.log(`   Subject: ${subject}`);

        if (DRY_RUN) {
            console.log('   [Dry Run] Would send email now.');
        } else {
            try {
                await transporter.sendMail({
                    from: process.env.SMTP_FROM || process.env.SMTP_USER,
                    to,
                    subject,
                    text: body,
                });
                console.log('   ✅ Sent!');
                
                // Move to sent folder
                fs.renameSync(filePath, path.join(SENT_DIR, file));
            } catch (err) {
                console.error(`   ❌ Failed: ${err.message}`);
            }
        }
        
        // Add a random delay to avoid rate limits (5-15 seconds)
        if (!DRY_RUN) {
            const delay = Math.floor(Math.random() * 10000) + 5000;
            console.log(`   ⏳ Waiting ${delay/1000}s...`);
            await new Promise(resolve => setTimeout(resolve, delay));
        }
    }
}

main();
