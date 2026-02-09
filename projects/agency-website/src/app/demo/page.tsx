import Link from "next/link";

export default function Demo() {
  return (
    <div className="min-h-screen bg-slate-50 font-sans text-slate-900">
        {/* Navigation Wrapper */}
        <nav className="fixed w-full z-50 bg-white border-b border-slate-200">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div className="flex justify-between h-16 items-center">
                    <div className="flex items-center gap-8">
                        <Link href="/" className="text-xl font-bold tracking-tight text-slate-900">
                        MANIFEST<span className="text-blue-600">.AGENCY</span>
                        </Link>
                        <span className="bg-slate-100 text-slate-500 text-xs px-2 py-1 rounded font-mono">
                            LIVE DEMO: AI RECEPTIONIST
                        </span>
                    </div>
                    <Link 
                        href="/book"
                        className="bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-blue-700 transition-colors"
                    >
                        Hire This Agent
                    </Link>
                </div>
            </div>
        </nav>

        {/* Dashboard Content */}
        <div className="pt-24 pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
            
            {/* Header */}
            <div className="flex justify-between items-end mb-8">
                <div>
                    <h1 className="text-2xl font-bold text-slate-900">Agent Status: Active 🟢</h1>
                    <p className="text-slate-500 text-sm mt-1">Role: <span className="font-mono text-blue-600">Dental Receptionist (Sarah)</span></p>
                </div>
                <div className="flex gap-2">
                    <button className="bg-white border border-slate-200 text-slate-600 px-3 py-2 rounded-lg text-sm font-medium hover:bg-slate-50">Last 24 Hours</button>
                    <button className="bg-white border border-slate-200 text-slate-600 px-3 py-2 rounded-lg text-sm font-medium hover:bg-slate-50">Export Logs</button>
                </div>
            </div>

            {/* KPI Cards */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
                <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
                    <div className="text-slate-500 text-sm font-medium mb-2">Calls Handled</div>
                    <div className="text-3xl font-bold text-slate-900">42</div>
                    <div className="text-green-600 text-sm font-medium mt-2">100% Answer Rate</div>
                </div>
                <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
                    <div className="text-slate-500 text-sm font-medium mb-2">Appointments Booked</div>
                    <div className="text-3xl font-bold text-slate-900">8</div>
                    <div className="text-green-600 text-sm font-medium mt-2">$3,600 Est. Revenue</div>
                </div>
                <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
                    <div className="text-slate-500 text-sm font-medium mb-2">Avg. Latency</div>
                    <div className="text-3xl font-bold text-slate-900">600ms</div>
                    <div className="text-slate-400 text-sm font-medium mt-2">Human-like speed</div>
                </div>
                <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
                    <div className="text-slate-500 text-sm font-medium mb-2">Transferred to Human</div>
                    <div className="text-3xl font-bold text-slate-900">3</div>
                    <div className="text-yellow-600 text-sm font-medium mt-2">Complex Medical Qs</div>
                </div>
            </div>

            {/* Main Content Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 mb-8">
                
                {/* Live Transcript (The "Wow" Factor) */}
                <div className="lg:col-span-2 bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col h-[500px]">
                    <div className="px-6 py-4 border-b border-slate-200 bg-slate-50 flex justify-between items-center">
                        <h3 className="font-bold text-slate-900">Live Call Transcript</h3>
                        <div className="flex items-center gap-2">
                            <span className="w-2 h-2 bg-red-500 rounded-full animate-pulse"></span>
                            <span className="text-xs text-red-500 font-bold uppercase">Recording</span>
                        </div>
                    </div>
                    
                    {/* Chat Bubble UI */}
                    <div className="flex-1 p-6 overflow-y-auto space-y-4 bg-slate-50/50">
                        <div className="flex gap-4">
                            <div className="w-8 h-8 rounded-full bg-slate-200 flex items-center justify-center text-xs font-bold">Usr</div>
                            <div className="bg-white p-3 rounded-r-xl rounded-bl-xl border border-slate-200 shadow-sm max-w-[80%] text-sm text-slate-700">
                                Hi, are you guys open on Saturdays? My tooth is killing me.
                            </div>
                        </div>
                        <div className="flex gap-4 flex-row-reverse">
                            <div className="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center text-xs font-bold text-white">AI</div>
                            <div className="bg-blue-600 p-3 rounded-l-xl rounded-br-xl shadow-md max-w-[80%] text-sm text-white">
                                I&apos;m so sorry to hear that! Yes, we are open this Saturday from 9 AM to 2 PM. Would you like me to squeeze you in for an emergency exam?
                            </div>
                        </div>
                        <div className="flex gap-4">
                            <div className="w-8 h-8 rounded-full bg-slate-200 flex items-center justify-center text-xs font-bold">Usr</div>
                            <div className="bg-white p-3 rounded-r-xl rounded-bl-xl border border-slate-200 shadow-sm max-w-[80%] text-sm text-slate-700">
                                Yes please. As early as possible.
                            </div>
                        </div>
                        <div className="flex gap-4 flex-row-reverse">
                            <div className="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center text-xs font-bold text-white">AI</div>
                            <div className="bg-blue-600 p-3 rounded-l-xl rounded-br-xl shadow-md max-w-[80%] text-sm text-white">
                                <span className="block text-blue-200 text-xs mb-1 font-mono">Thinking (R1)... Checking Calendar...</span>
                                I have a slot at 9:15 AM with Dr. Chen. Does that work for you?
                            </div>
                        </div>
                        <div className="flex gap-4">
                            <div className="w-8 h-8 rounded-full bg-slate-200 flex items-center justify-center text-xs font-bold">Usr</div>
                            <div className="bg-white p-3 rounded-r-xl rounded-bl-xl border border-slate-200 shadow-sm max-w-[80%] text-sm text-slate-700">
                                Perfect. I&apos;ll take it.
                            </div>
                        </div>
                        <div className="flex gap-4 flex-row-reverse">
                            <div className="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center text-xs font-bold text-white">AI</div>
                            <div className="bg-blue-600 p-3 rounded-l-xl rounded-br-xl shadow-md max-w-[80%] text-sm text-white">
                                <span className="block text-blue-200 text-xs mb-1 font-mono">Action: book_appointment(&apos;9:15&apos;, &apos;Saturday&apos;)</span>
                                You&apos;re all set for 9:15 AM Saturday. I&apos;ll send a confirmation text now. Feel better!
                            </div>
                        </div>
                    </div>
                </div>

                {/* Call Log / History */}
                <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm h-[500px] flex flex-col">
                    <h3 className="text-lg font-bold text-slate-900 mb-4">Recent Calls</h3>
                    <div className="flex-1 overflow-y-auto pr-2">
                        <div className="space-y-3">
                            {[
                                { time: "2 mins ago", caller: "(512) 555-0123", intent: "Emergency", status: "Booked", duration: "1m 42s" },
                                { time: "15 mins ago", caller: "(512) 555-0987", intent: "Pricing", status: "Resolved", duration: "45s" },
                                { time: "1 hour ago", caller: "(210) 555-3321", intent: "Reschedule", status: "Booked", duration: "2m 10s" },
                                { time: "2 hours ago", caller: "(512) 555-4455", intent: "Spam", status: "Blocked", duration: "12s" },
                                { time: "3 hours ago", caller: "(737) 555-9988", intent: "Insurance", status: "Transferred", duration: "3m 05s" },
                            ].map((call, i) => (
                                <div key={i} className="p-3 border border-slate-100 rounded-lg hover:bg-slate-50 transition-colors cursor-pointer group">
                                    <div className="flex justify-between items-start mb-1">
                                        <span className="font-mono text-xs text-slate-500">{call.time}</span>
                                        <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                                            call.status === 'Booked' ? 'bg-green-100 text-green-700' :
                                            call.status === 'Blocked' ? 'bg-red-100 text-red-700' :
                                            'bg-blue-100 text-blue-700'
                                        }`}>{call.status}</span>
                                    </div>
                                    <div className="font-medium text-slate-900">{call.caller}</div>
                                    <div className="text-sm text-slate-500 flex justify-between mt-1">
                                        <span>{call.intent}</span>
                                        <span>{call.duration}</span>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            </div>

            <div className="mt-12 text-center">
                <p className="text-slate-600 mb-4">
                    This is what &quot;Staffing 2.0&quot; looks like.
                </p>
                <Link 
                    href="/book"
                    className="inline-block bg-slate-900 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-slate-800 transition-colors"
                >
                    Deploy Your Agent
                </Link>
            </div>

        </div>
    </div>
  );
}
