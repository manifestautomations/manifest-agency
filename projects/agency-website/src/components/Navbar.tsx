import Link from "next/link";

export default function Navbar() {
  return (
    <nav className="fixed w-full z-50 bg-white/80 backdrop-blur-md border-b border-slate-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16 items-center">
          <Link href="/" className="text-xl font-bold tracking-tight text-slate-900">
            MANIFEST<span className="text-blue-600">.AGENCY</span>
          </Link>
          <div className="hidden md:flex space-x-8">
            <Link href="/#problem" className="text-sm font-medium text-slate-600 hover:text-blue-600">
              The Problem
            </Link>
            <Link href="/services" className="text-sm font-medium text-slate-600 hover:text-blue-600">
              Services
            </Link>
            <Link href="/#pricing" className="text-sm font-medium text-slate-600 hover:text-blue-600">
              Pricing
            </Link>
            <Link href="/calculator" className="text-sm font-medium text-slate-600 hover:text-blue-600">
              ROI Calculator
            </Link>
          </div>
          <Link
            href="/book"
            className="bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-blue-700 transition-colors"
          >
            Book Audit
          </Link>
        </div>
      </div>
    </nav>
  );
}
