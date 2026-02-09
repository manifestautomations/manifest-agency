import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

export default function Privacy() {
  return (
    <div className="min-h-screen bg-white text-slate-900 font-sans flex flex-col">
      <Navbar />

      <main className="flex-grow pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto prose prose-slate">
          <h1>Privacy Policy</h1>
          <p className="lead">Last updated: January 29, 2026</p>

          <h2>1. Introduction</h2>
          <p>
            Manifest Automations (&quot;we&quot;, &quot;us&quot;, or &quot;our&quot;) respects your privacy. This Privacy Policy explains how we collect, use, and share information about you when you visit our website or use our services.
          </p>

          <h2>2. Information We Collect</h2>
          <p>
            We collect information you provide directly to us, such as when you:
          </p>
          <ul>
            <li>Fill out our contact or calculator forms (Name, Email, Company info).</li>
            <li>Book a consultation via Calendly.</li>
            <li>Subscribe to our newsletter.</li>
          </ul>

          <h2>3. How We Use Your Information</h2>
          <p>
            We use the information we collect to:
          </p>
          <ul>
            <li>Provide, maintain, and improve our services.</li>
            <li>Respond to your comments and questions.</li>
            <li>Send you technical notices, updates, and support messages.</li>
            <li>Communicate with you about products, services, offers, and events.</li>
          </ul>

          <h2>4. Data Security</h2>
          <p>
            We implement reasonable security measures to protect your information. However, no security system is impenetrable and we cannot guarantee the security of our systems 100%.
          </p>

          <h2>5. Contact Us</h2>
          <p>
            If you have any questions about this Privacy Policy, please contact us at: <a href="mailto:hello@manifestautomations.com">hello@manifestautomations.com</a>.
          </p>
        </div>
      </main>

      <Footer />
    </div>
  );
}
