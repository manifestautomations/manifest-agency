import fs from 'fs';
import path from 'path';
import matter from 'gray-matter';
import { remark } from 'remark';
import html from 'remark-html';

// Assuming process.cwd() is projects/agency-website/
const caseStudiesDirectory = path.join(process.cwd(), '../../content/case-studies');

export interface CaseStudyData {
  slug: string;
  title: string;
  client: string;
  industry: string;
  service: string;
  results: string[];
  contentHtml?: string;
}

export function getSortedCaseStudies(): CaseStudyData[] {
  // Check if directory exists
  if (!fs.existsSync(caseStudiesDirectory)) {
    console.warn(`Case studies directory not found: ${caseStudiesDirectory}`);
    return [];
  }

  const fileNames = fs.readdirSync(caseStudiesDirectory);
  const allCaseStudies = fileNames.map((fileName) => {
    // Remove ".md" from file name to get slug
    const slug = fileName.replace(/\.md$/, '');

    // Read markdown file as string
    const fullPath = path.join(caseStudiesDirectory, fileName);
    const fileContents = fs.readFileSync(fullPath, 'utf8');

    // Use gray-matter to parse the post metadata section
    const matterResult = matter(fileContents);

    // Combine the data with the slug
    return {
      slug,
      ...(matterResult.data as Omit<CaseStudyData, 'slug' | 'contentHtml'>),
    };
  });

  return allCaseStudies;
}

export async function getCaseStudyData(slug: string): Promise<CaseStudyData> {
  const fullPath = path.join(caseStudiesDirectory, `${slug}.md`);
  
  if (!fs.existsSync(fullPath)) {
    throw new Error(`Case study not found: ${slug}`);
  }

  const fileContents = fs.readFileSync(fullPath, 'utf8');

  // Use gray-matter to parse the post metadata section
  const matterResult = matter(fileContents);

  // Use remark to convert markdown into HTML string
  const processedContent = await remark()
    .use(html)
    .process(matterResult.content);
  const contentHtml = processedContent.toString();

  return {
    slug,
    contentHtml,
    ...(matterResult.data as Omit<CaseStudyData, 'slug' | 'contentHtml'>),
  };
}
