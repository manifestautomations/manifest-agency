import fs from 'fs';
import path from 'path';
import matter from 'gray-matter';

// Assuming process.cwd() is projects/agency-website/
const testimonialsDirectory = path.join(process.cwd(), '../../content/testimonials');

export interface TestimonialData {
  slug: string;
  name: string;
  role: string;
  quote: string;
  rating: number;
}

export function getSortedTestimonials(): TestimonialData[] {
  // Check if directory exists
  if (!fs.existsSync(testimonialsDirectory)) {
    console.warn(`Testimonials directory not found: ${testimonialsDirectory}`);
    return [];
  }

  const fileNames = fs.readdirSync(testimonialsDirectory);
  const allTestimonials = fileNames.map((fileName) => {
    // Remove ".md" from file name to get slug
    const slug = fileName.replace(/\.md$/, '');

    // Read markdown file as string
    const fullPath = path.join(testimonialsDirectory, fileName);
    const fileContents = fs.readFileSync(fullPath, 'utf8');

    // Use gray-matter to parse the post metadata section
    const matterResult = matter(fileContents);

    // Combine the data with the slug
    return {
      slug,
      ...(matterResult.data as Omit<TestimonialData, 'slug'>),
    };
  });

  return allTestimonials;
}
