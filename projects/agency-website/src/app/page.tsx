import Link from "next/link";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { getSortedCaseStudies } from "@/lib/case-studies";

export default function Home() {
  const caseStudies = getSortedCaseStudies();

  return (
    <div className="min-h-screen bg-white text-slate-900 font-sans">
      <Navbar />

      {/* Hero Section */}
      <section className="relative pt-32 pb-20 lg:pt-48 lg:pb-32 overflow-hidden">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10 text-center">
          <h1 className="text-5xl md:text-7xl font-extrabold tracking-tight text-slate-900 mb-6">
            Stop Hiring Humans <br />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-indigo-600">
              For Robot Work.
            </span>
          </h1>
          <p className="mt-4 text-xl text-slate-600 max-w-2xl mx-auto mb-10">
            We deploy autonomous AI Recruiters, SDRs, and Receptionists that speak, sell, and work 24/7. Scale your agency without scaling your headcount.
          </p>
          <div className="flex justify-center gap-4">
            <Link 
              href="/book"
              className="bg-blue-600 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-blue-700 transition-all shadow-lg hover:shadow-blue-500/25"
            >
              Hire an AI Agent
            </Link>
            <Link 
              href="/demo"
              className="bg-white text-slate-700 border border-slate-200 px-8 py-4 rounded-lg text-lg font-semibold hover:bg-slate-50 transition-all"
            >
              Hear Them Speak
            </Link>
          </div>
        </div>
      </section>

      {/* The Problem */}
      <section id="problem" className="py-20 bg-slate-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">
              Your Team is Drowning in &quot;Busy Work&quot;
            </h2>
            <p className="mt-4 text-lg text-slate-600">
              You hired smart people to strategize. Why are they answering phones and screening resumes?
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            <div className="bg-white p-8 rounded-xl shadow-sm border border-slate-100">
              <div className="w-12 h-12 bg-red-100 rounded-lg flex items-center justify-center mb-6">
                <span className="text-2xl">📞</span>
              </div>
              <h3 className="text-xl font-bold text-slate-900 mb-3">Missed Calls = Lost Revenue</h3>
              <p className="text-slate-600">
                30% of calls go to voicemail. For a dental clinic or law firm, that&apos;s $10k/mo in lost deals.
              </p>
            </div>
            <div className="bg-white p-8 rounded-xl shadow-sm border border-slate-100">
              <div className="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center mb-6">
                <span className="text-2xl">📄</span>
              </div>
              <h3 className="text-xl font-bold text-slate-900 mb-3">Resume Fatigue</h3>
              <p className="text-slate-600">
                Recruiters spend 6 seconds per resume. They miss the best candidates because they are overwhelmed.
              </p>
            </div>
            <div className="bg-white p-8 rounded-xl shadow-sm border border-slate-100">
              <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mb-6">
                <span className="text-2xl">📧</span>
              </div>
              <h3 className="text-xl font-bold text-slate-900 mb-3">Outbound is Broken</h3>
              <p className="text-slate-600">
                SDRs burn out after 3 months. Spamming generic emails doesn&apos;t work anymore. You need hyper-personalization.
              </p>
            </div>
          </div>
          
          <div className="mt-12 text-center">
            <p className="text-2xl font-bold text-slate-900">
              There is a better way. Enter the AI Workforce.
            </p>
          </div>
        </div>
      </section>

      {/* The Solution (Verticals) */}
      <section id="solution" className="py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="lg:grid lg:grid-cols-2 lg:gap-16 items-center">
            <div>
              <h2 className="text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl mb-6">
                AI Staffing & Growth Infrastructure.
              </h2>
              <p className="text-lg text-slate-600 mb-8">
                We don&apos;t just give you a login. We deploy fully-trained agents that integrate into your existing team.
              </p>
              
              <div className="space-y-8">
                <div className="flex gap-4">
                  <div className="flex-shrink-0 w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-bold text-xl">🎤</div>
                  <div>
                    <h4 className="font-bold text-slate-900 text-lg">Voice AI Agents</h4>
                    <p className="text-slate-600 mt-1">
                      **AI Recruiter:** Screens candidates via phone, ranks them by culture fit.<br/>
                      **AI Receptionist:** Answers 24/7, books appointments in your calendar.<br/>
                      **AI SDR:** Cold calls leads with &lt;500ms latency and human-like pause handling.
                    </p>
                  </div>
                </div>
                <div className="flex gap-4">
                  <div className="flex-shrink-0 w-10 h-10 rounded-full bg-green-100 flex items-center justify-center text-green-600 font-bold text-xl">📈</div>
                  <div>
                    <h4 className="font-bold text-slate-900 text-lg">The Growth Stack</h4>
                    <p className="text-slate-600 mt-1">
                      **pSEO Engine:** Deploys 1,000s of &quot;Best Agency in [City]&quot; landing pages.<br/>
                      **Sales Triage:** Enriches inbound leads and drafts personalized emails instantly.
                    </p>
                  </div>
                </div>
              </div>
            </div>
            
            {/* Code Snippet / Tech Demo */}
            <div className="mt-12 lg:mt-0 bg-slate-900 p-8 rounded-2xl shadow-2xl text-slate-300 font-mono text-sm">
              <div className="flex gap-2 mb-4">
                <div className="w-3 h-3 rounded-full bg-red-500"></div>
                <div className="w-3 h-3 rounded-full bg-yellow-500"></div>
                <div className="w-3 h-3 rounded-full bg-green-500"></div>
              </div>
              <p><span className="text-purple-400">const</span> <span className="text-blue-400">recruiter</span> = <span className="text-yellow-300">new</span> Agent(&#123;</p>
              <p className="pl-4">role: <span className="text-green-300">&apos;Senior Recruiter&apos;</span>,</p>
              <p className="pl-4">voice: <span className="text-green-300">&apos;Sarah_V2&apos;</span>,</p>
              <p className="pl-4">tools: [<span className="text-green-300">&apos;calendar&apos;</span>, <span className="text-green-300">&apos;ats_sync&apos;</span>]</p>
              <p>&#125;);</p>
              <br/>
              <p><span className="text-slate-500">{`// 📞 Incoming call from candidate...`}</span></p>
              <p><span className="text-blue-400">recruiter</span>.<span className="text-yellow-300">listen</span>();</p>
              <p><span className="text-green-400">&quot;Hey! I saw your React experience. Can you tell me about a time you optimized a slow render?&quot;</span></p>
              <br/>
              <p><span className="text-slate-500">{`// 🧠 Reasoning (DeepSeek R1)...`}</span></p>
              <p><span className="text-purple-400">Analysis:</span> Candidate explained `useMemo` correctly but missed `React.memo`.</p>
              <p><span className="text-blue-400">Score:</span> 8/10. <span className="text-green-400">✓ Passing to Hiring Manager.</span></p>
            </div>
          </div>
        </div>
      </section>

      {/* Case Studies */}
      <section id="results" className="py-20 bg-slate-50 border-y border-slate-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">
              Real Results.
            </h2>
            <p className="mt-4 text-lg text-slate-600">
              See how we help agencies reclaim their time.
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-12">
            {caseStudies.map((study) => (
              <Link href={`/case-studies/${study.slug}`} key={study.slug} className="block group">
                <div className="bg-white rounded-2xl p-8 border border-slate-200 group-hover:border-blue-500 transition-colors h-full shadow-sm">
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
                  <div className="bg-slate-50 rounded-xl p-4 border border-slate-100 flex items-center justify-between">
                    <span className="text-blue-600 font-semibold text-sm">Read Case Study &rarr;</span>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* Pricing / CTA */}
      <section id="pricing" className="py-20 bg-slate-900 text-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl mb-6">
            Ready to Automate Your Agency?
          </h2>
          <p className="text-xl text-slate-300 mb-10">
            We operate on an &quot;Earned Autonomy&quot; model. <br/>
            Start with a pilot. Scale as we prove ROI.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link 
              href="/book"
              className="bg-blue-600 text-white px-8 py-4 rounded-lg text-lg font-bold hover:bg-blue-700 transition-all shadow-xl"
            >
              Book a Strategy Call
            </Link>
            <Link 
              href="/demo"
              className="bg-slate-800 text-white border border-slate-700 px-8 py-4 rounded-lg text-lg font-bold hover:bg-slate-700 transition-all"
            >
              Try the Voice Demo
            </Link>
          </div>
        </div>
      </section>

      <Footer />
    </div>
  );
}
