import Link from "next/link";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

export default function NotFound() {
  return (
    <div className="min-h-screen bg-slate-900 text-white font-sans flex flex-col">
      <Navbar />

      <main className="flex-grow flex items-center justify-center px-4 sm:px-6 lg:px-8 py-24">
        <div className="text-center max-w-2xl">
          <div className="text-9xl font-extrabold text-blue-600/20 tracking-tighter mb-8">
            404
          </div>
          <h1 className="text-4xl font-extrabold tracking-tight text-white sm:text-5xl mb-6">
            Lost in the data?
          </h1>
          <p className="text-xl text-slate-400 mb-10">
            It looks like this page has been archived, deleted, or never existed in our schema.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
             <Link 
              href="/"
              className="bg-blue-600 text-white px-8 py-3 rounded-lg text-lg font-semibold hover:bg-blue-700 transition-all"
            >
              Back to Home
            </Link>
            <Link 
              href="/book"
              className="bg-transparent border border-slate-600 text-white px-8 py-3 rounded-lg text-lg font-semibold hover:bg-slate-800 transition-all"
            >
              Book an Audit
            </Link>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
}
