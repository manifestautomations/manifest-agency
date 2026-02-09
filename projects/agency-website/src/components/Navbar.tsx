import Link from "next/link";

export default function Navbar() {
  return (
    <nav className="fixed w-full z-50 bg-white/80 backdrop-blur-md border-b border-slate-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16 items-center">
          <Link href="/" className="text-xl font-bold tracking-tight text-slate-900">
            MANIFEST<span className="text-blue-600">.AGENCY</span>
          </Link>
          <div className="hidden md:flex space-x-8 items-center">
            <Link href="/#problem" className="text-sm font-medium text-slate-600 hover:text-blue-600 transition-colors">
              The Problem
            </Link>
            <Link href="/services" className="text-sm font-medium text-slate-600 hover:text-blue-600 transition-colors">
              AI Staffing
            </Link>
            <Link href="/#pricing" className="text-sm font-medium text-slate-600 hover:text-blue-600 transition-colors">
              Pricing
            </Link>
            <Link href="/demo" className="text-sm font-medium text-slate-600 hover:text-blue-600 transition-colors">
              Voice Demo
            </Link>
          </div>
          <div className="flex items-center gap-4">
            <Link
              href="/book"
              className="bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-bold hover:bg-blue-700 transition-colors shadow-sm"
            >
              Hire an Agent
            </Link>
          </div>
        </div>
      </div>
    </nav>
  );
}
