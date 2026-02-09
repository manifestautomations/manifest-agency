import Link from "next/link";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

export default function Services() {
  return (
    <div className="min-h-screen bg-white text-slate-900 font-sans">
      <Navbar />

      {/* Hero Section */}
      <section className="pt-32 pb-20 px-4 sm:px-6 lg:px-8 bg-slate-50">
        <div className="max-w-4xl mx-auto text-center">
          <h1 className="text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl mb-6">
            We Build The Machine. <br />
            <span className="text-blue-600">You Drive The Growth.</span>
          </h1>
          <p className="text-xl text-slate-600 mb-8 max-w-2xl mx-auto">
            Stop stitching together zaps and spreadsheets. We deploy enterprise-grade data infrastructure that scales with your agency.
          </p>
          <div className="flex justify-center gap-4">
             <Link 
              href="/book"
              className="bg-blue-600 text-white px-8 py-3 rounded-lg text-lg font-semibold hover:bg-blue-700 transition-all"
            >
              Start Building
            </Link>
          </div>
        </div>
      </section>

      {/* Service 1: Ingestion */}
      <section className="py-20 border-b border-slate-100">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="lg:grid lg:grid-cols-2 lg:gap-16 items-center">
            <div>
              <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mb-6 text-2xl">
                🔌
              </div>
              <h2 className="text-3xl font-bold tracking-tight text-slate-900 mb-4">
                Automated Ingestion
              </h2>
              <p className="text-lg text-slate-600 mb-6">
                Your client data lives in silos—Facebook Ads, Shopify, HubSpot, Google Sheets. We build robust pipelines that centralize everything automatically.
              </p>
              <ul className="space-y-3 text-slate-600">
                <li className="flex gap-3">
                    <span className="text-blue-600 font-bold">✓</span>
                    No more &quot;Export to CSV&quot;
                </li>
                <li className="flex gap-3">
                    <span className="text-blue-600 font-bold">✓</span>
                    Connectors for 300+ platforms
                </li>
                <li className="flex gap-3">
                    <span className="text-blue-600 font-bold">✓</span>
                    Real-time or batch syncs
                </li>
              </ul>
            </div>
            <div className="mt-12 lg:mt-0 bg-slate-900 p-8 rounded-2xl shadow-xl border border-slate-800">
               <div className="flex items-center gap-4 mb-6 border-b border-slate-800 pb-4">
                    <div className="w-3 h-3 rounded-full bg-red-500"></div>
                    <div className="w-3 h-3 rounded-full bg-yellow-500"></div>
                    <div className="w-3 h-3 rounded-full bg-green-500"></div>
                    <div className="text-slate-500 font-mono text-xs ml-auto">pipeline.yaml</div>
               </div>
               <pre className="font-mono text-sm text-blue-300 overflow-x-auto">
{`sources:
  - name: facebook_ads
    type: airbyte/source-facebook-marketing
    config:
      access_token: \${FB_TOKEN}
      account_id: \${FB_ACCOUNT_ID}
  
  - name: shopify_store
    type: airbyte/source-shopify
    config:
      shop: my-client-store`}
               </pre>
            </div>
          </div>
        </div>
      </section>

      {/* Service 2: Warehousing & Transformation */}
      <section className="py-20 border-b border-slate-100 bg-slate-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="lg:grid lg:grid-cols-2 lg:gap-16 items-center">
             <div className="order-2 lg:order-1 mt-12 lg:mt-0 bg-white p-8 rounded-2xl shadow-lg border border-slate-200">
                <div className="space-y-4">
                    <div className="flex items-center justify-between p-4 bg-slate-50 rounded-lg border border-slate-100">
                        <span className="font-mono text-slate-600">raw_orders</span>
                        <span className="text-slate-400">→</span>
                        <span className="font-mono text-blue-600 font-bold">stg_orders</span>
                    </div>
                    <div className="flex items-center justify-between p-4 bg-slate-50 rounded-lg border border-slate-100">
                        <span className="font-mono text-slate-600">stg_orders</span>
                        <span className="text-slate-400">→</span>
                        <span className="font-mono text-purple-600 font-bold">fct_revenue</span>
                    </div>
                     <div className="text-center text-slate-400 text-sm pt-2">
                        dbt DAG (Directed Acyclic Graph)
                     </div>
                </div>
            </div>
            <div className="order-1 lg:order-2">
              <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mb-6 text-2xl">
                🏗️
              </div>
              <h2 className="text-3xl font-bold tracking-tight text-slate-900 mb-4">
                Warehousing & Transformation
              </h2>
              <p className="text-lg text-slate-600 mb-6">
                Raw data is messy. We use modern tools like dbt and BigQuery/Snowflake to clean, model, and standardize your data into a &quot;Single Source of Truth&quot;.
              </p>
              <ul className="space-y-3 text-slate-600">
                <li className="flex gap-3">
                    <span className="text-blue-600 font-bold">✓</span>
                    Standardize currency & dates
                </li>
                <li className="flex gap-3">
                    <span className="text-blue-600 font-bold">✓</span>
                    Version-controlled logic (Git)
                </li>
                <li className="flex gap-3">
                    <span className="text-blue-600 font-bold">✓</span>
                    Automated testing & documentation
                </li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* Service 3: Visualization */}
      <section className="py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="lg:grid lg:grid-cols-2 lg:gap-16 items-center">
            <div>
              <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mb-6 text-2xl">
                📊
              </div>
              <h2 className="text-3xl font-bold tracking-tight text-slate-900 mb-4">
                Business Intelligence
              </h2>
              <p className="text-lg text-slate-600 mb-6">
                Stop manually updating PowerPoint slides. We connect your clean data to Looker, Tableau, or PowerBI for real-time, interactive dashboards.
              </p>
              <ul className="space-y-3 text-slate-600">
                <li className="flex gap-3">
                    <span className="text-blue-600 font-bold">✓</span>
                    Client-facing portals
                </li>
                <li className="flex gap-3">
                    <span className="text-blue-600 font-bold">✓</span>
                    Automated email reports
                </li>
                <li className="flex gap-3">
                    <span className="text-blue-600 font-bold">✓</span>
                    Self-serve analytics for your team
                </li>
              </ul>
            </div>
             <div className="mt-12 lg:mt-0 relative group">
                <Link href="/demo" className="block cursor-pointer">
                    <div className="absolute inset-0 bg-blue-600 blur-2xl opacity-10 group-hover:opacity-20 transition-opacity rounded-full"></div>
                    <div className="relative bg-white p-2 rounded-xl shadow-2xl border border-slate-100 rotate-2 group-hover:rotate-0 transition-transform duration-500">
                        {/* Abstract Dashboard UI */}
                        <div className="bg-slate-50 rounded-lg p-6 space-y-6 relative overflow-hidden">
                             {/* Overlay Badge */}
                             <div className="absolute inset-0 flex items-center justify-center bg-white/50 opacity-0 group-hover:opacity-100 transition-opacity z-10 backdrop-blur-sm">
                                <span className="bg-blue-600 text-white px-6 py-3 rounded-lg font-bold shadow-lg transform scale-95 group-hover:scale-100 transition-transform">
                                    View Live Demo
                                </span>
                             </div>

                            <div className="flex gap-4">
                                <div className="flex-1 bg-white p-4 rounded shadow-sm">
                                    <div className="h-2 w-16 bg-slate-200 rounded mb-2"></div>
                                    <div className="h-6 w-24 bg-blue-100 rounded text-blue-600 font-bold flex items-center px-2">24.5% ↗</div>
                                </div>
                                <div className="flex-1 bg-white p-4 rounded shadow-sm">
                                    <div className="h-2 w-16 bg-slate-200 rounded mb-2"></div>
                                    <div className="h-6 w-24 bg-green-100 rounded text-green-600 font-bold flex items-center px-2">$1.2M</div>
                                </div>
                            </div>
                            <div className="bg-white p-4 rounded shadow-sm h-32 flex items-end justify-between px-4 pb-2">
                                <div className="w-4 bg-blue-200 h-12 rounded-t"></div>
                                <div className="w-4 bg-blue-300 h-16 rounded-t"></div>
                                <div className="w-4 bg-blue-400 h-24 rounded-t"></div>
                                <div className="w-4 bg-blue-500 h-20 rounded-t"></div>
                                <div className="w-4 bg-blue-600 h-28 rounded-t"></div>
                            </div>
                        </div>
                    </div>
                </Link>
            </div>
          </div>
        </div>
      </section>

      {/* Tech Stack Logos */}
      <section className="py-16 bg-slate-900 text-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
            <p className="text-slate-400 uppercase tracking-widest text-sm font-semibold mb-8">
                Our Toolbelt
            </p>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-8 items-center opacity-70 grayscale hover:grayscale-0 transition-all duration-500">
                <div className="text-xl font-bold">Fivetran</div>
                <div className="text-xl font-bold">Airbyte</div>
                <div className="text-xl font-bold">Snowflake</div>
                <div className="text-xl font-bold">BigQuery</div>
                <div className="text-xl font-bold">dbt</div>
                <div className="text-xl font-bold">Looker</div>
                <div className="text-xl font-bold">Tableau</div>
                <div className="text-xl font-bold">PowerBI</div>
            </div>
        </div>
      </section>

      <Footer />
    </div>
  );
}
