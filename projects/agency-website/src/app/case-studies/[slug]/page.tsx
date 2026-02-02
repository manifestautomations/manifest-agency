import { getCaseStudyData } from '@/lib/case-studies';
import { notFound } from 'next/navigation';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import Link from 'next/link';

interface Props {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { slug } = await params;
  try {
    const post = await getCaseStudyData(slug);
    return {
      title: `${post.title} | Manifest Agency Case Study`,
      description: `How we helped ${post.client} achieve ${post.results[0]} via ${post.service}.`,
    };
  } catch (e) {
    return {
      title: 'Case Study Not Found',
    };
  }
}

export default async function CaseStudy({ params }: Props) {
  const { slug } = await params;
  let post;
  
  try {
    post = await getCaseStudyData(slug);
  } catch (e) {
    notFound();
  }

  return (
    <div className="min-h-screen bg-white font-sans text-slate-900">
      <Navbar />
      
      <main className="pt-32 pb-20">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          
          {/* Header */}
          <div className="text-center mb-16">
            <div className="inline-block px-3 py-1 rounded-full bg-blue-50 text-blue-600 text-sm font-semibold mb-4">
              {post.industry}
            </div>
            <h1 className="text-4xl md:text-6xl font-extrabold text-slate-900 mb-6 tracking-tight">
              {post.title}
            </h1>
            <p className="text-xl text-slate-600">
              Client: <span className="font-semibold text-slate-900">{post.client}</span>
            </p>
          </div>

          {/* Results Grid */}
          <div className="grid md:grid-cols-3 gap-6 mb-16">
            {post.results.map((result, i) => (
              <div key={i} className="bg-slate-50 border border-slate-200 p-6 rounded-xl text-center shadow-sm">
                <div className="text-lg font-bold text-green-600">{result}</div>
              </div>
            ))}
          </div>

          {/* Content */}
          <div className="prose prose-lg prose-slate mx-auto" dangerouslySetInnerHTML={{ __html: post.contentHtml || '' }} />
          
          {/* CTA */}
          <div className="mt-20 p-8 bg-slate-900 rounded-2xl text-center text-white shadow-xl">
            <h2 className="text-2xl font-bold mb-4">Want similar results?</h2>
            <p className="mb-8 text-slate-300">We can deploy the same {post.service} architecture for you.</p>
            <Link 
              href="/book"
              className="inline-block bg-blue-600 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-blue-700 transition-all shadow-lg hover:shadow-blue-500/25"
            >
              Book a Strategy Call
            </Link>
          </div>

        </div>
      </main>

      <Footer />
    </div>
  );
}
