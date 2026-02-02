import { MetadataRoute } from 'next';
import { getSortedPostsData } from '../lib/posts';

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = 'https://manifest.agency';
  const posts = getSortedPostsData();

  const blogPosts = posts.map((post) => ({
    url: `${baseUrl}/blog/${post.slug}`,
    lastModified: new Date(post.date),
    changeFrequency: 'monthly' as const,
    priority: 0.7,
  }));

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

  return [...routes, ...blogPosts];
}
