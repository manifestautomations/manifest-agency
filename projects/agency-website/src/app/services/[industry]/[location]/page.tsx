import { notFound } from 'next/navigation';
import Link from 'next/link';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import fs from 'fs';
import path from 'path';

// Define the interface for our data structure
interface Industry {
  slug: string;
  name: string;
  pain_point: string;
  solution: string;
  value_prop: string;
  stats?: { label: string; value: string; source: string }[];
}

interface Location {
  slug: string;
  name: string;
  state: string;
}

interface PageProps {
  params: Promise<{
    industry: string;
    location: string;
  }>;
}

// Helper to load data
async function getData() {
  const filePath = path.join(process.cwd(), '../../content/pseo-data.json');
  const fileContents = fs.readFileSync(filePath, 'utf8');
  return JSON.parse(fileContents);
}

export async function generateStaticParams() {
  const data = await getData();
  const params: { industry: string; location: string }[] = [];

  data.industries.forEach((industry: Industry) => {
    data.locations.forEach((location: Location) => {
      params.push({
        industry: industry.slug,
        location: location.slug,
      });
    });
  });

  return params;
}

export async function generateMetadata({ params }: PageProps) {
  const resolvedParams = await params;
  const data = await getData();
  const industry = data.industries.find((i: Industry) => i.slug === resolvedParams.industry);
  const location = data.locations.find((l: Location) => l.slug === resolvedParams.location);

  if (!industry || !location) return {};

  return {
    title: `AI Automation for ${industry.name} in ${location.name} | Manifest`,
    description: `Stop losing ${industry.pain_point} in ${location.name}. Our AI agents automate your workflows.`,
  };
}

export default async function Page({ params }: PageProps) {
  const resolvedParams = await params;
  const data = await getData();
  const industry = data.industries.find((i: Industry) => i.slug === resolvedParams.industry);
  const location = data.locations.find((l: Location) => l.slug === resolvedParams.location);

  if (!industry || !location) {
    notFound();
  }

  return (
    <div className="min-h-screen bg-white text-slate-900 font-sans">
      <Navbar />

      {/* Hero Section */}
      <section className="pt-32 pb-20 px-4 sm:px-6 lg:px-8 bg-slate-50 border-b border-slate-100">
        <div className="max-w-7xl mx-auto text-center">
          <div className="inline-block bg-blue-100 text-blue-700 px-4 py-1 rounded-full text-sm font-semibold mb-6">
            For {industry.name} in {location.name}, {location.state}
          </div>
          <h1 className="text-5xl md:text-6xl font-extrabold tracking-tight text-slate-900 mb-6">
            Stop Losing <span className="text-transparent bg-clip-text bg-gradient-to-r from-red-600 to-orange-600">{industry.pain_point}</span>.
          </h1>
          <p className="mt-4 text-xl text-slate-600 max-w-2xl mx-auto mb-10">
            We build <strong>{industry.solution}s</strong> that run 24/7. {industry.value_prop}
          </p>
          <div className="flex justify-center gap-4">
            <Link 
              href="/book"
              className="bg-blue-600 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-blue-700 transition-all shadow-lg hover:shadow-blue-500/25"
            >
              Automate My Agency
            </Link>
          </div>
        </div>
      </section>

      {/* GEO / Stats Section (AI Optimized) */}
      {industry.stats && (
        <section className="py-16 bg-white">
          <div className="max-w-4xl mx-auto px-4">
            <h2 className="text-3xl font-bold text-center mb-12">Why {location.name} {industry.name} Need Automation</h2>
            <div className="grid md:grid-cols-3 gap-8">
              {industry.stats.map((stat: { label: string; value: string; source: string }, index: number) => (
                <div key={index} className="p-6 bg-slate-50 rounded-xl border border-slate-200 text-center">
                  <div className="text-4xl font-extrabold text-blue-600 mb-2">{stat.value}</div>
                  <div className="font-semibold text-slate-900">{stat.label}</div>
                  <div className="text-xs text-slate-500 mt-2">Source: {stat.source}</div>
                </div>
              ))}
            </div>
          </div>
        </section>
      )}

      {/* Local Context Section */}
      <section className="py-20 bg-slate-900 text-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl font-bold mb-6">Serving Clients in {location.name}</h2>
          <p className="text-xl text-slate-300 max-w-2xl mx-auto">
            Manifest Automations helps forward-thinking {industry.name} across {location.state} reclaim their time.
            Whether you are downtown or in the suburbs, our digital workers operate in the cloud, instantly scaling your operations.
          </p>
        </div>
      </section>

      <Footer />
    </div>
  );
}
