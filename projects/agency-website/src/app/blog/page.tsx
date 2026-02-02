import Link from "next/link";
import { getSortedPostsData } from "../../lib/posts";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

export default function BlogIndex() {
  const posts = getSortedPostsData();

  return (
    <div className="min-h-screen bg-white text-slate-900 font-sans">
      <Navbar />

      {/* Main Content */}
      <div className="pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <div className="text-center mb-16">
            <h1 className="text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl mb-4">
              Insights
            </h1>
            <p className="text-xl text-slate-600">
              Thoughts on automation, agency scaling, and the future of work.
            </p>
          </div>

          <div className="space-y-12">
            {posts.map((post) => (
              <article key={post.slug} className="flex flex-col items-start justify-between border-b border-slate-100 pb-12">
                <div className="flex items-center gap-x-4 text-xs">
                  <time dateTime={post.date} className="text-slate-500">
                    {post.date}
                  </time>
                  {post.tags && post.tags.map(tag => (
                    <span key={tag} className="relative z-10 rounded-full bg-slate-50 px-3 py-1.5 font-medium text-slate-600 hover:bg-slate-100">
                      {tag}
                    </span>
                  ))}
                </div>
                <div className="group relative">
                  <h3 className="mt-3 text-lg font-semibold leading-6 text-slate-900 group-hover:text-slate-600">
                    <Link href={`/blog/${post.slug}`}>
                      <span className="absolute inset-0" />
                      {post.title}
                    </Link>
                  </h3>
                  <p className="mt-5 line-clamp-3 text-sm leading-6 text-slate-600">
                    {post.excerpt || post.description}
                  </p>
                </div>
                <div className="relative mt-8 flex items-center gap-x-4">
                  <div className="text-sm leading-6">
                    <p className="font-semibold text-slate-900">
                      <span className="absolute inset-0" />
                      {post.author}
                    </p>
                  </div>
                </div>
              </article>
            ))}

            {posts.length === 0 && (
              <div className="text-center text-slate-500">
                No posts found. Check back soon.
              </div>
            )}
          </div>
        </div>
      </div>
      
      <Footer />
    </div>
  );
}
