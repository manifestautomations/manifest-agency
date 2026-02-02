import { MetadataRoute } from 'next';
import { getSortedPostsData } from '../lib/posts';
import path from 'path';
import fs from 'fs';

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = 'https://manifest.agency';
  const posts = getSortedPostsData();

  // Blog Posts
  const blogPosts = posts.map((post) => ({
    url: `${baseUrl}/blog/${post.slug}`,
    lastModified: new Date(post.date),
    changeFrequency: 'monthly' as const,
    priority: 0.7,
  }));

  // Static Routes
  const routes = [
    '',
    '/services',
    '/calculator',
    '/demo',
    '/book',
    '/blog',
  ].map((route) => ({
    url: `${baseUrl}${route}`,
    lastModified: new Date(),
    changeFrequency: 'weekly' as const,
    priority: route === '' ? 1 : 0.8,
  }));

  // pSEO Routes (Generated from content/pseo-data.json)
  let pseoRoutes: MetadataRoute.Sitemap = [];
  try {
    // Note: Adjust path if deployed structure differs
    const pseoDataPath = path.join(process.cwd(), '../../content/pseo-data.json');
    if (fs.existsSync(pseoDataPath)) {
      const data = JSON.parse(fs.readFileSync(pseoDataPath, 'utf8'));
      if (data.industries && data.locations) {
        data.industries.forEach((ind: any) => {
          data.locations.forEach((loc: any) => {
            pseoRoutes.push({
              url: `${baseUrl}/services/${ind.slug}/${loc.slug}`,
              lastModified: new Date(),
              changeFrequency: 'monthly' as const,
              priority: 0.9, // High priority for landing pages
            });
          });
        });
      }
    }
  } catch (error) {
    console.warn('Could not load pSEO data for sitemap:', error);
  }

  return [...routes, ...blogPosts, ...pseoRoutes];
}
