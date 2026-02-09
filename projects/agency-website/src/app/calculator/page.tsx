"use client";

import { useState } from "react";
import Link from "next/link";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

export default function Calculator() {
  const [analysts, setAnalysts] = useState(3);
  const [hourlyRate, setHourlyRate] = useState(50);
  const [hoursPerWeek, setHoursPerWeek] = useState(10);

  // State and logic defined below
  const [email, setEmail] = useState("");
  const [isSubmitted, setIsSubmitted] = useState(false);

  const weeklyCost = analysts * hourlyRate * hoursPerWeek;
  const annualCost = weeklyCost * 52;
  const fiveYearCost = annualCost * 5;
  const annualSavings = annualCost * 0.8;

  const handleDetailedReport = (e: React.FormEvent) => {
    e.preventDefault();
    // In a real app, send to API/Zapier
    console.log("Lead Captured:", email, { analysts, hourlyRate, hoursPerWeek, annualSavings });
    setIsSubmitted(true);
  };


  return (
    <div className="min-h-screen bg-white text-slate-900 font-sans">
      <Navbar />

      {/* Main Content */}
      <div className="pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <div className="text-center mb-12">
            <h1 className="text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl mb-4">
              The Cost of &quot;Manual Labor&quot;
            </h1>
            <p className="text-xl text-slate-600">
              See how much you are paying smart people to do robot work.
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-12 items-start">
            {/* Controls */}
            <div className="bg-slate-50 p-8 rounded-2xl border border-slate-200 space-y-8">
              <div>
                <label className="block text-sm font-semibold text-slate-700 mb-2">
                  Number of Team Members
                </label>
                <input 
                  type="range" 
                  min="1" 
                  max="50" 
                  value={analysts} 
                  onChange={(e) => setAnalysts(parseInt(e.target.value))}
                  className="w-full h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-blue-600"
                />
                <div className="mt-2 text-right font-mono font-bold text-blue-600 text-lg">
                  {analysts} people
                </div>
              </div>

              <div>
                <label className="block text-sm font-semibold text-slate-700 mb-2">
                  Average Hourly Cost (Fully Loaded)
                </label>
                <input 
                  type="range" 
                  min="20" 
                  max="200" 
                  step="5"
                  value={hourlyRate} 
                  onChange={(e) => setHourlyRate(parseInt(e.target.value))}
                  className="w-full h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-blue-600"
                />
                <div className="mt-2 text-right font-mono font-bold text-blue-600 text-lg">
                  ${hourlyRate}/hr
                </div>
                <p className="text-xs text-slate-500 mt-1">Include salary, benefits, overhead.</p>
              </div>

              <div>
                <label className="block text-sm font-semibold text-slate-700 mb-2">
                  Hours/Week on Data Entry & Reporting
                </label>
                <input 
                  type="range" 
                  min="1" 
                  max="40" 
                  value={hoursPerWeek} 
                  onChange={(e) => setHoursPerWeek(parseInt(e.target.value))}
                  className="w-full h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-blue-600"
                />
                <div className="mt-2 text-right font-mono font-bold text-blue-600 text-lg">
                  {hoursPerWeek} hrs/week
                </div>
                <p className="text-xs text-slate-500 mt-1">Per person. Be honest.</p>
              </div>
            </div>

            {/* Results */}
            <div className="space-y-6">
              <div className="bg-slate-900 text-white p-8 rounded-2xl shadow-xl">
                <div className="text-slate-400 text-sm font-medium uppercase tracking-wider mb-2">Annual Wasted Spend</div>
                <div className="text-5xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-red-400 to-orange-400">
                  ${annualCost.toLocaleString()}
                </div>
                <div className="mt-4 pt-4 border-t border-slate-700 text-slate-300 text-sm">
                  That&apos;s <span className="font-bold text-white">${fiveYearCost.toLocaleString()}</span> over 5 years.
                </div>
              </div>

              <div className="bg-blue-50 border border-blue-100 p-8 rounded-2xl">
                <h3 className="text-lg font-bold text-blue-900 mb-2">The Automation Opportunity</h3>
                <p className="text-blue-700 mb-6">
                  By automating these workflows, you could reclaim:
                </p>
                <div className="flex items-baseline gap-2 mb-2">
                  <span className="text-4xl font-bold text-blue-600">${annualSavings.toLocaleString()}</span>
                  <span className="text-blue-600 font-medium">per year</span>
                </div>
                <p className="text-sm text-blue-600/80 mb-6">
                  (Assuming 80% automation rate)
                </p>
                
                {/* Email Capture or CTA */}
                {!isSubmitted ? (
                    <form onSubmit={handleDetailedReport} className="space-y-4">
                         <div>
                            <label htmlFor="email" className="sr-only">Email address</label>
                            <input
                                id="email"
                                name="email"
                                type="email"
                                autoComplete="email"
                                required
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                className="w-full px-4 py-3 rounded-lg border border-blue-200 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
                                placeholder="Enter work email for full report"
                            />
                        </div>
                        <button 
                            type="submit"
                            className="block w-full text-center bg-blue-600 hover:bg-blue-700 text-white py-3 rounded-lg font-semibold transition-colors"
                        >
                            Get Detailed PDF Report
                        </button>
                        <p className="text-xs text-blue-600/60 text-center">
                            Or <Link href="/book" className="underline hover:text-blue-800">book a call directly</Link>.
                        </p>
                    </form>
                ) : (
                    <div className="bg-green-100 border border-green-200 rounded-lg p-4 text-center">
                        <div className="text-green-700 font-bold mb-1">Report Sent!</div>
                        <p className="text-green-600 text-sm mb-4">Check your inbox for the breakdown.</p>
                         <Link 
                            href="/book"
                            className="block w-full text-center bg-green-600 hover:bg-green-700 text-white py-2 rounded-lg font-semibold transition-colors text-sm"
                        >
                            Schedule Review Call
                        </Link>
                    </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
      
      {/* Footer is optional on tool pages, but good for consistency. Let's add it. */}
      <Footer />
    </div>
  );
}
