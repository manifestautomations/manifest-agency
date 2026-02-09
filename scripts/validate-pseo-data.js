/**
 * Validate pSEO Data
 * Ensures integrity of the industries and locations dataset.
 * 
 * Usage: node scripts/validate-pseo-data.js
 */

const fs = require('fs');
const path = require('path');

const DATA_PATH = path.join(__dirname, '../content/pseo-data.json');

function validate() {
  console.log('🔍 Validating pSEO Data...');

  if (!fs.existsSync(DATA_PATH)) {
    console.error(`❌ Data file not found at: ${DATA_PATH}`);
    process.exit(1);
  }

  const data = JSON.parse(fs.readFileSync(DATA_PATH, 'utf8'));
  const errors = [];

  // Validate Industries
  if (!data.industries || !Array.isArray(data.industries)) {
    errors.push('❌ "industries" must be an array.');
  } else {
    const industrySlugs = new Set();
    data.industries.forEach((ind, i) => {
      const context = `Industry[${i}]`;
      if (!ind.slug) errors.push(`${context} missing "slug".`);
      if (!ind.name) errors.push(`${context} missing "name".`);
      if (!ind.pain_point) errors.push(`${context} missing "pain_point".`);
      if (!ind.solution) errors.push(`${context} missing "solution".`);
      if (!ind.value_prop) errors.push(`${context} missing "value_prop".`);
      
      // Validate Stats (New for GEO)
      if (!ind.stats || !Array.isArray(ind.stats)) {
        errors.push(`${context} missing "stats" array (Required for GEO).`);
      } else {
        ind.stats.forEach((stat, s) => {
            if (!stat.label) errors.push(`${context}.stats[${s}] missing "label".`);
            if (!stat.value) errors.push(`${context}.stats[${s}] missing "value".`);
            if (!stat.source) errors.push(`${context}.stats[${s}] missing "source".`);
        });
      }

      if (industrySlugs.has(ind.slug)) {
        errors.push(`${context} duplicate slug: "${ind.slug}".`);
      }
      industrySlugs.add(ind.slug);
    });
  }

  // Validate Locations
  if (!data.locations || !Array.isArray(data.locations)) {
    errors.push('❌ "locations" must be an array.');
  } else {
    const locationSlugs = new Set();
    data.locations.forEach((loc, i) => {
      const context = `Location[${i}]`;
      if (!loc.slug) errors.push(`${context} missing "slug".`);
      if (!loc.name) errors.push(`${context} missing "name".`);
      if (!loc.state) errors.push(`${context} missing "state".`);

      if (locationSlugs.has(loc.slug)) {
        errors.push(`${context} duplicate slug: "${loc.slug}".`);
      }
      locationSlugs.add(loc.slug);
    });
  }

  if (errors.length > 0) {
    console.error('\n❌ Validation Failed:');
    errors.forEach(err => console.error(err));
    process.exit(1);
  } else {
    const permutationCount = data.industries.length * data.locations.length;
    console.log(`\n✅ Validation Passed!`);
    console.log(`   Industries: ${data.industries.length}`);
    console.log(`   Locations:  ${data.locations.length}`);
    console.log(`   Total Pages: ${permutationCount}`);
    console.log(`   GEO Ready:   Yes (Stats present)`);
  }
}

validate();
