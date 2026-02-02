import Link from "next/link";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

export default function Book() {
  return (
    <div className="min-h-screen bg-white text-slate-900 font-sans flex flex-col">
      <Navbar />

      <main className="flex-grow pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto text-center">
          <h1 className="text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl mb-6">
            Let's Talk Engineering.
          </h1>
          <p className="text-xl text-slate-600 mb-12">
            No salespeople. No slide decks. Just a 30-minute conversation about your data bottlenecks and how to fix them.
          </p>
          
          <div className="bg-slate-50 p-8 rounded-2xl border border-slate-200 shadow-sm mb-12">
            <h2 className="text-lg font-bold text-slate-900 mb-4">What to expect:</h2>
            <ul className="text-left space-y-4 max-w-md mx-auto mb-8 text-slate-600">
              <li className="flex gap-3">
                <span className="text-blue-600 font-bold">✓</span>
                <span>Review of your current reporting workflow</span>
              </li>
              <li className="flex gap-3">
                <span className="text-blue-600 font-bold">✓</span>
                <span>Identification of automation opportunities</span>
              </li>
              <li className="flex gap-3">
                <span className="text-blue-600 font-bold">✓</span>
                <span>Rough architecture sketch & ROI estimate</span>
              </li>
            </ul>
            
            <a 
              href="https://calendly.com/manifest-automations/30min"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-block bg-blue-600 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-blue-700 transition-all shadow-lg hover:shadow-blue-500/25"
            >
              Select a Time on Calendly
            </a>
            <p className="mt-4 text-sm text-slate-500">
              Opens in a new tab.
            </p>
          </div>

          <div className="text-slate-500 text-sm">
            Prefer email? <a href="mailto:hello@manifestautomations.com" className="text-blue-600 hover:underline">hello@manifestautomations.com</a>
          </div>
        </div>
      </main>
      
      <Footer />
    </div>
  );
}
