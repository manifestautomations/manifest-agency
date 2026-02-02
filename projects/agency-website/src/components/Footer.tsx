import Link from "next/link";

export default function Footer() {
  return (
    <footer id="contact" className="bg-white py-20 border-t border-slate-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h2 className="text-3xl font-bold text-slate-900 mb-8">
          Ready to Automate Your Operations?
        </h2>
        <p className="text-slate-600 mb-8 max-w-2xl mx-auto">
          Let's look at your current process. If we can't automate it, we'll
          tell you. No sales pressure. Just engineering.
        </p>
        <a
          href="mailto:hello@manifestautomations.com"
          className="text-2xl font-bold text-blue-600 hover:underline"
        >
          hello@manifestautomations.com
        </a>
        <div className="mt-12 text-slate-400 text-sm">
          <Link href="/blog" className="hover:text-blue-600 mr-4">
            Insights
          </Link>
          <Link href="/privacy" className="hover:text-blue-600 mr-4">
            Privacy Policy
          </Link>
          <Link href="/terms" className="hover:text-blue-600 mr-4">
            Terms of Service
          </Link>
          © 2026 Manifest Automations. All rights reserved.
        </div>
      </div>
    </footer>
  );
}
