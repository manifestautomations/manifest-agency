import { getPostData, getSortedPostsData } from "../../../lib/posts";
import Link from "next/link";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

export async function generateStaticParams() {
  const posts = getSortedPostsData();
  return posts.map((post) => ({
    slug: post.slug,
  }));
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const postData = await getPostData(slug);
  
  return {
    title: `${postData.title} | Manifest Agency`,
    description: postData.excerpt || postData.description,
    openGraph: {
       title: postData.title,
       description: postData.excerpt || postData.description,
       type: 'article',
       publishedTime: postData.date,
       authors: [postData.author],
    }
  };
}

export default async function Post({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const postData = await getPostData(slug);

  return (
    <div className="min-h-screen bg-white text-slate-900 font-sans">
      <Navbar />

      <article className="pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto">
          <div className="mb-10 text-center">
             <div className="flex justify-center gap-2 mb-4">
                {postData.tags && postData.tags.map(tag => (
                    <span key={tag} className="rounded-full bg-blue-50 px-3 py-1 text-sm font-medium text-blue-600">
                        {tag}
                    </span>
                ))}
             </div>
            <h1 className="text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl mb-4">
              {postData.title}
            </h1>
            <div className="text-slate-500">
              {postData.date} • By {postData.author}
            </div>
          </div>

          <div 
            className="prose prose-lg prose-slate mx-auto"
            dangerouslySetInnerHTML={{ __html: postData.contentHtml || '' }}
          />
          
          <div className="mt-16 pt-8 border-t border-slate-200 text-center">
            <h3 className="text-xl font-bold text-slate-900 mb-4">Want to implement this?</h3>
            <p className="text-slate-600 mb-6">
                We build the systems we write about. Let's discuss your agency's architecture.
            </p>
            <Link 
              href="/book"
              className="inline-block bg-blue-600 text-white px-8 py-3 rounded-lg font-semibold hover:bg-blue-700 transition-colors"
            >
              Book Technical Audit
            </Link>
          </div>
        </div>
      </article>

      <Footer />
    </div>
  );
}
