import React from 'react';
import Link from 'next/link';

export default function RecruiterLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen bg-gray-50">
      {/* Sidebar */}
      <aside className="w-64 bg-white border-r border-gray-200 hidden md:block">
        <div className="p-6">
          <h2 className="text-xl font-bold text-gray-900">AI Recruiter</h2>
          <p className="text-sm text-gray-500">v1.0.0 (Beta)</p>
        </div>
        <nav className="mt-6 px-4 space-y-2">
          <Link href="/recruiter" className="block px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg">
            Dashboard
          </Link>
          <Link href="/recruiter/jobs" className="block px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg">
            Jobs
          </Link>
          <Link href="/recruiter/candidates" className="block px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg">
            Candidates
          </Link>
          <Link href="/recruiter/settings" className="block px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg">
            Settings
          </Link>
        </nav>
      </aside>

      {/* Main Content */}
      <main className="flex-1 p-8">
        {children}
      </main>
    </div>
  );
}
