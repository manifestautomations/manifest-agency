import Link from "next/link";
import Navbar from "@/components/Navbar"; // Keep main navbar for the demo wrapper? Or make it full screen app?
// Let's make it look like a full screen app but keep the wrapper so they can navigate back.

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
                            LIVE DEMO ENVIRONMENT
                        </span>
                    </div>
                    <Link 
                        href="/book"
                        className="bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-blue-700 transition-colors"
                    >
                        Get This For Your Agency
                    </Link>
                </div>
            </div>
        </nav>

        {/* Dashboard Content */}
        <div className="pt-24 pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
            
            {/* Header */}
            <div className="flex justify-between items-end mb-8">
                <div>
                    <h1 className="text-2xl font-bold text-slate-900">Client Performance: Acme Corp</h1>
                    <p className="text-slate-500 text-sm mt-1">Last synced: 2 minutes ago via <span className="font-mono text-blue-600">pipeline-acme-prod</span></p>
                </div>
                <div className="flex gap-2">
                    {/* TODO: Connect to Supabase Storage for CSV export */}
                    <button className="bg-white border border-slate-200 text-slate-600 px-3 py-2 rounded-lg text-sm font-medium hover:bg-slate-50">Last 30 Days</button>
                    <button className="bg-white border border-slate-200 text-slate-600 px-3 py-2 rounded-lg text-sm font-medium hover:bg-slate-50">Export CSV</button>
                </div>
            </div>

            {/* KPI Cards */}
            {/* Data Source: calculated from `formatted_campaigns` view in BigQuery/Supabase */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
                <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
                    <div className="text-slate-500 text-sm font-medium mb-2">Total Spend</div>
                    <div className="text-3xl font-bold text-slate-900">$142,394</div>
                    <div className="text-green-600 text-sm font-medium mt-2">↑ 12.5% vs last month</div>
                </div>
                <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
                    <div className="text-slate-500 text-sm font-medium mb-2">ROAS</div>
                    <div className="text-3xl font-bold text-slate-900">4.2x</div>
                    <div className="text-green-600 text-sm font-medium mt-2">↑ 0.8x vs last month</div>
                </div>
                <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
                    <div className="text-slate-500 text-sm font-medium mb-2">Conversions</div>
                    <div className="text-3xl font-bold text-slate-900">1,842</div>
                    <div className="text-red-500 text-sm font-medium mt-2">↓ 2.1% vs last month</div>
                </div>
                <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
                    <div className="text-slate-500 text-sm font-medium mb-2">CPA</div>
                    <div className="text-3xl font-bold text-slate-900">$77.30</div>
                    <div className="text-green-600 text-sm font-medium mt-2">↓ $5.20 vs last month</div>
                </div>
            </div>

            {/* Main Charts */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 mb-8">
                {/* Chart 1 */}
                <div className="lg:col-span-2 bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
                    <h3 className="text-lg font-bold text-slate-900 mb-6">Spend vs. Revenue (Daily)</h3>
                    <div className="h-64 flex items-end gap-2">
                        {/* Fake Bar Chart */}
                        {[...Array(20)].map((_, i) => {
                            const height = Math.floor(Math.random() * 60) + 20;
                            const height2 = Math.floor(Math.random() * 80) + 20;
                            return (
                                <div key={i} className="flex-1 flex flex-col justify-end gap-1 h-full group relative">
                                    <div style={{ height: `${height2}%` }} className="bg-blue-100 w-full rounded-t hover:bg-blue-200 transition-colors"></div>
                                    <div style={{ height: `${height}%` }} className="bg-blue-600 w-full rounded-t hover:bg-blue-700 transition-colors"></div>
                                </div>
                            )
                        })}
                    </div>
                    <div className="flex justify-between mt-4 text-xs text-slate-400 font-mono">
                        <span>Jan 01</span>
                        <span>Jan 15</span>
                        <span>Jan 30</span>
                    </div>
                </div>

                {/* Platform Breakdown */}
                <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
                    <h3 className="text-lg font-bold text-slate-900 mb-6">Platform Mix</h3>
                    <div className="space-y-4">
                        <div className="group">
                            <div className="flex justify-between text-sm mb-1">
                                <span className="font-medium text-slate-700">Meta Ads</span>
                                <span className="text-slate-500">$84,200 (59%)</span>
                            </div>
                            <div className="w-full bg-slate-100 rounded-full h-2">
                                <div className="bg-blue-600 h-2 rounded-full" style={{ width: '59%' }}></div>
                            </div>
                        </div>
                        <div className="group">
                            <div className="flex justify-between text-sm mb-1">
                                <span className="font-medium text-slate-700">Google Ads</span>
                                <span className="text-slate-500">$42,100 (30%)</span>
                            </div>
                            <div className="w-full bg-slate-100 rounded-full h-2">
                                <div className="bg-red-500 h-2 rounded-full" style={{ width: '30%' }}></div>
                            </div>
                        </div>
                        <div className="group">
                            <div className="flex justify-between text-sm mb-1">
                                <span className="font-medium text-slate-700">TikTok Ads</span>
                                <span className="text-slate-500">$11,500 (8%)</span>
                            </div>
                            <div className="w-full bg-slate-100 rounded-full h-2">
                                <div className="bg-slate-900 h-2 rounded-full" style={{ width: '8%' }}></div>
                            </div>
                        </div>
                        <div className="group">
                            <div className="flex justify-between text-sm mb-1">
                                <span className="font-medium text-slate-700">Email (Klaviyo)</span>
                                <span className="text-slate-500">$4,594 (3%)</span>
                            </div>
                            <div className="w-full bg-slate-100 rounded-full h-2">
                                <div className="bg-green-500 h-2 rounded-full" style={{ width: '3%' }}></div>
                            </div>
                        </div>
                    </div>

                    <div className="mt-8 pt-8 border-t border-slate-100">
                        <div className="flex items-center gap-3 bg-blue-50 p-4 rounded-lg">
                            <div className="text-2xl">💡</div>
                            <div className="text-sm text-blue-800">
                                <strong>Insight:</strong> Google Ads ROAS is up 15% this week. Consider shifting budget from TikTok.
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            {/* Data Table */}
            {/* 
                Implementation Note:
                In production, this table is hydrated by a Supabase Realtime subscription 
                to the `kpi_daily_summary` materialized view.
            */}
            <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                <div className="px-6 py-4 border-b border-slate-200 bg-slate-50 flex justify-between items-center">
                    <h3 className="font-bold text-slate-900">Campaign Performance</h3>
                    <div className="text-xs text-slate-500 font-mono">Synced: 12:42:01 PM UTC</div>
                </div>
                <table className="w-full text-sm text-left">
                    <thead className="bg-slate-50 text-slate-500 font-medium">
                        <tr>
                            <th className="px-6 py-3">Campaign Name</th>
                            <th className="px-6 py-3">Platform</th>
                            <th className="px-6 py-3">Status</th>
                            <th className="px-6 py-3 text-right">Spend</th>
                            <th className="px-6 py-3 text-right">Rev</th>
                            <th className="px-6 py-3 text-right">ROAS</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                        {[
                            { name: "US_Prospecting_Broad_v2", platform: "Meta", status: "Active", spend: "$12,402", rev: "$42,100", roas: "3.4" },
                            { name: "Retargeting_DPA_Catalog", platform: "Meta", status: "Active", spend: "$4,200", rev: "$28,400", roas: "6.7" },
                            { name: "Brand_Search_Exact", platform: "Google", status: "Active", spend: "$1,100", rev: "$12,400", roas: "11.2" },
                            { name: "YouTube_Shorts_Test", platform: "Google", status: "Learning", spend: "$800", rev: "$900", roas: "1.1" },
                            { name: "TikTok_UGC_Spark", platform: "TikTok", status: "Paused", spend: "$2,400", rev: "$1,800", roas: "0.75" },
                        ].map((row, i) => (
                            <tr key={i} className="hover:bg-slate-50 transition-colors">
                                <td className="px-6 py-4 font-medium text-slate-900">{row.name}</td>
                                <td className="px-6 py-4 text-slate-500">{row.platform}</td>
                                <td className="px-6 py-4">
                                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                                        row.status === 'Active' ? 'bg-green-100 text-green-700' : 
                                        row.status === 'Paused' ? 'bg-slate-100 text-slate-600' :
                                        'bg-yellow-100 text-yellow-700'
                                    }`}>
                                        {row.status}
                                    </span>
                                </td>
                                <td className="px-6 py-4 text-right font-mono text-slate-600">{row.spend}</td>
                                <td className="px-6 py-4 text-right font-mono text-slate-600">{row.rev}</td>
                                <td className="px-6 py-4 text-right font-bold text-slate-900">{row.roas}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            <div className="mt-12 text-center">
                <p className="text-slate-600 mb-4">
                    Stop manually building this report every Monday.
                </p>
                <Link 
                    href="/book"
                    className="inline-block bg-slate-900 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-slate-800 transition-colors"
                >
                    Build This For Me
                </Link>
            </div>

        </div>
    </div>
  );
}
