import Link from "next/link";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { getSortedCaseStudies } from "@/lib/case-studies";
import { getSortedTestimonials } from "@/lib/testimonials";

export default function Home() {
  const caseStudies = getSortedCaseStudies();
  const testimonials = getSortedTestimonials();

  return (
    <div className="min-h-screen bg-white text-slate-900 font-sans">
      <Navbar />

      {/* Hero Section */}
      <section className="relative pt-32 pb-20 lg:pt-48 lg:pb-32 overflow-hidden">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10 text-center">
          <h1 className="text-5xl md:text-7xl font-extrabold tracking-tight text-slate-900 mb-6">
            Stop Hiring Analysts <br />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-indigo-600">
              To Do Robot Work.
            </span>
          </h1>
          <p className="mt-4 text-xl text-slate-600 max-w-2xl mx-auto mb-10">
            We build automated data pipelines that ingest, clean, and report your client data instantly. Scale your agency without scaling your headcount.
          </p>
          <div className="flex justify-center gap-4">
            <Link 
              href="/book"
              className="bg-blue-600 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-blue-700 transition-all shadow-lg hover:shadow-blue-500/25"
            >
              Book a Technical Audit
            </Link>
            <Link 
              href="/demo"
              className="bg-white text-slate-700 border border-slate-200 px-8 py-4 rounded-lg text-lg font-semibold hover:bg-slate-50 transition-all"
            >
              View Live Demo
            </Link>
          </div>
        </div>
      </section>

      {/* The Problem */}
      <section id="problem" className="py-20 bg-slate-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">
              Is Your Growth Bottlenecked by Spreadsheets?
            </h2>
            <p className="mt-4 text-lg text-slate-600">
              You signed the client. You have the strategy. But your team is drowning in data chaos.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            <div className="bg-white p-8 rounded-xl shadow-sm border border-slate-100">
              <div className="w-12 h-12 bg-red-100 rounded-lg flex items-center justify-center mb-6">
                <span className="text-2xl">🐌</span>
              </div>
              <h3 className="text-xl font-bold text-slate-900 mb-3">Slow Onboarding</h3>
              <p className="text-slate-600">
                Does it take 40+ hours to map a new client's data? That's a week of lost value.
              </p>
            </div>
            <div className="bg-white p-8 rounded-xl shadow-sm border border-slate-100">
              <div className="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center mb-6">
                <span className="text-2xl">💸</span>
              </div>
              <h3 className="text-xl font-bold text-slate-900 mb-3">Wasted Talent</h3>
              <p className="text-slate-600">
                Are your expensive analysts spending 60% of their time cleaning CSVs instead of analyzing?
              </p>
            </div>
            <div className="bg-white p-8 rounded-xl shadow-sm border border-slate-100">
              <div className="w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center mb-6">
                <span className="text-2xl">💥</span>
              </div>
              <h3 className="text-xl font-bold text-slate-900 mb-3">Fragile Systems</h3>
              <p className="text-slate-600">
                Does your entire reporting flow break when a client changes one column name?
              </p>
            </div>
          </div>
          
          <div className="mt-12 text-center">
            <p className="text-2xl font-bold text-slate-900">
              You don't need more people. You need better plumbing.
            </p>
          </div>
        </div>
      </section>

      {/* Case Studies */}
      <section id="results" className="py-20 bg-white border-y border-slate-100">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">
              Real Results. No Fluff.
            </h2>
            <p className="mt-4 text-lg text-slate-600">
              See how we help agencies reclaim their time.
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-12">
            {caseStudies.map((study) => (
              <Link href={`/case-studies/${study.slug}`} key={study.slug} className="block group">
                <div className="bg-slate-50 rounded-2xl p-8 border border-slate-200 group-hover:border-blue-500 transition-colors h-full">
                  <div className="flex items-center gap-4 mb-6">
                    <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-2xl">
                      {study.industry === 'Dental' ? '🦷' : study.industry === 'E-Commerce' ? '🛒' : '📈'}
                    </div>
                    <div>
                      <h3 className="font-bold text-slate-900 text-lg group-hover:text-blue-600 transition-colors">{study.title}</h3>
                      <p className="text-sm text-slate-500">{study.client}</p>
                    </div>
                  </div>
                  <div className="space-y-4 mb-8">
                    <div>
                      <h4 className="font-semibold text-slate-900 text-sm uppercase tracking-wide">Results</h4>
                      <ul className="text-slate-600 mt-1 list-disc pl-4 space-y-1">
                        {study.results.map((r, i) => (
                          <li key={i}>{r}</li>
                        ))}
                      </ul>
                    </div>
                  </div>
                  <div className="bg-white rounded-xl p-4 border border-slate-100 shadow-sm flex items-center justify-between">
                    <span className="text-blue-600 font-semibold text-sm">Read Case Study &rarr;</span>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section className="py-20 bg-slate-900 text-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
              Trusted by Data-Driven Agencies.
            </h2>
          </div>
          <div className="grid md:grid-cols-3 gap-8">
            {testimonials.map((t) => (
              <div key={t.slug} className="bg-slate-800 p-8 rounded-2xl border border-slate-700">
                <div className="flex gap-1 text-yellow-400 mb-4">
                  {[...Array(t.rating)].map((_, i) => (
                    <span key={i}>★</span>
                  ))}
                </div>
                <p className="text-slate-300 mb-6 italic">"{t.quote}"</p>
                <div className="font-bold">{t.name}</div>
                <div className="text-sm text-slate-500">{t.role}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* The Solution */}
      <section id="solution" className="py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="lg:grid lg:grid-cols-2 lg:gap-16 items-center">
            <div>
              <h2 className="text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl mb-6">
                Automated Data Infrastructure for High-Growth Agencies.
              </h2>
              <p className="text-lg text-slate-600 mb-8">
                We are not consultants who give you a slide deck. We are engineers who build the machine you wish you had.
              </p>
              
              <div className="space-y-6">
                <div className="flex gap-4">
                  <div className="flex-shrink-0 w-6 h-6 rounded-full bg-green-100 flex items-center justify-center text-green-600 font-bold text-sm">✓</div>
                  <div>
                    <h4 className="font-bold text-slate-900">Automated Ingestion</h4>
                    <p className="text-slate-600 text-sm mt-1">Stop the email-to-Excel shuffle. We build secure connectors that pull data instantly.</p>
                  </div>
                </div>
                <div className="flex gap-4">
                  <div className="flex-shrink-0 w-6 h-6 rounded-full bg-green-100 flex items-center justify-center text-green-600 font-bold text-sm">✓</div>
                  <div>
                    <h4 className="font-bold text-slate-900">Intelligent ETL</h4>
                    <p className="text-slate-600 text-sm mt-1">Our pipelines standardize wild formats (CSV, XML, JSON) into a single source of truth.</p>
                  </div>
                </div>
                <div className="flex gap-4">
                  <div className="flex-shrink-0 w-6 h-6 rounded-full bg-green-100 flex items-center justify-center text-green-600 font-bold text-sm">✓</div>
                  <div>
                    <h4 className="font-bold text-slate-900">Live BI Integration</h4>
                    <p className="text-slate-600 text-sm mt-1">Feed DOMO, Tableau, or PowerBI directly. Dashboards update in real-time.</p>
                  </div>
                </div>
              </div>
            </div>
            <div className="mt-12 lg:mt-0 bg-slate-900 p-8 rounded-2xl shadow-2xl text-slate-300 font-mono text-sm">
              <div className="flex gap-2 mb-4">
                <div className="w-3 h-3 rounded-full bg-red-500"></div>
                <div className="w-3 h-3 rounded-full bg-yellow-500"></div>
                <div className="w-3 h-3 rounded-full bg-green-500"></div>
              </div>
              <p><span className="text-purple-400">const</span> <span className="text-blue-400">pipeline</span> = <span className="text-yellow-300">await</span> manifest.<span className="text-blue-300">createPipeline</span>(&#123;</p>
              <p className="pl-4">source: <span className="text-green-300">'client_ftp'</span>,</p>
              <p className="pl-4">format: <span className="text-green-300">'csv_messy'</span>,</p>
              <p className="pl-4">destination: <span className="text-green-300">'bigquery'</span>,</p>
              <p className="pl-4">schedule: <span className="text-green-300">'@hourly'</span></p>
              <p>&#125;);</p>
              <br/>
              <p><span className="text-slate-500">// 🚀 Deploying worker...</span></p>
              <p><span className="text-green-400">✓ Ingestion active</span></p>
              <p><span className="text-green-400">✓ Cleaning logic applied</span></p>
              <p><span className="text-green-400">✓ Dashboard updated (14ms)</span></p>
            </div>
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" className="py-20 bg-slate-900 text-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
              Pay for Results, Not Hours.
            </h2>
            <p className="mt-4 text-lg text-slate-400">
              We offer two ways to engage, depending on your maturity.
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-8 max-w-4xl mx-auto">
            {/* Card 1 */}
            <div className="bg-slate-800 p-8 rounded-2xl border border-slate-700 hover:border-blue-500 transition-colors">
              <div className="flex items-center gap-3 mb-4">
                <span className="text-3xl">🛠️</span>
                <h3 className="text-2xl font-bold">Project-Based</h3>
              </div>
              <p className="text-slate-400 mb-6 min-h-[50px]">
                Best for solving a specific, burning bottleneck (e.g. "Fix our onboarding").
              </p>
              <div className="text-3xl font-bold mb-8">Flat Fee</div>
              <ul className="space-y-4 mb-8 text-slate-300">
                <li className="flex gap-3"><span>✓</span> Fixed deliverables</li>
                <li className="flex gap-3"><span>✓</span> 4-8 week timeline</li>
                <li className="flex gap-3"><span>✓</span> You own the code forever</li>
              </ul>
              <Link href="/book" className="block w-full text-center bg-slate-700 hover:bg-slate-600 text-white py-3 rounded-lg font-semibold transition-colors">
                Start a Sprint
              </Link>
            </div>

            {/* Card 2 */}
            <div className="bg-slate-800 p-8 rounded-2xl border border-blue-500 relative overflow-hidden">
              <div className="absolute top-0 right-0 bg-blue-600 text-white text-xs font-bold px-3 py-1 rounded-bl-lg">POPULAR</div>
              <div className="flex items-center gap-3 mb-4">
                <span className="text-3xl">🤖</span>
                <h3 className="text-2xl font-bold">Earned Autonomy</h3>
              </div>
              <p className="text-slate-400 mb-6 min-h-[50px]">
                A dedicated AI Agent (or team) that learns your business and scales with you.
              </p>
              <div className="text-3xl font-bold mb-8">$2k - $8k<span className="text-lg font-normal text-slate-400">/mo</span></div>
              <ul className="space-y-4 mb-8 text-slate-300">
                <li className="flex gap-3"><span>✓</span> Ongoing operations</li>
                <li className="flex gap-3"><span>✓</span> Scales from "Intern" to "Partner"</li>
                <li className="flex gap-3"><span>✓</span> Cancel anytime</li>
              </ul>
              <Link href="/book" className="block w-full text-center bg-blue-600 hover:bg-blue-700 text-white py-3 rounded-lg font-semibold transition-colors">
                Hire Your Digital Team
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* Lead Magnet / ROI Calculator Teaser */}
      <section className="py-20 bg-blue-600">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl font-bold tracking-tight text-white sm:text-4xl mb-6">
            Get the "Automation ROI Calculator"
          </h2>
          <p className="text-xl text-blue-100 mb-10 max-w-2xl mx-auto">
            See exactly how much margin you're losing to manual work. 
            Our free tool calculates your potential savings in seconds.
          </p>
          <Link 
            href="/calculator"
            className="inline-block bg-white text-blue-600 px-8 py-4 rounded-lg text-lg font-bold hover:bg-blue-50 transition-all shadow-xl"
          >
            Calculate Your Savings
          </Link>
        </div>
      </section>

      <Footer />
    </div>
  );
}
