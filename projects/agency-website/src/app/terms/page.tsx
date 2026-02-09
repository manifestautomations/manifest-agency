import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

export default function Terms() {
  return (
    <div className="min-h-screen bg-white text-slate-900 font-sans flex flex-col">
      <Navbar />

      <main className="flex-grow pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto prose prose-slate">
          <h1>Terms of Service</h1>
          <p className="lead">Last updated: January 29, 2026</p>

          <h2>1. Acceptance of Terms</h2>
          <p>
            By accessing and using the website and services of Manifest Automations (&quot;we&quot;, &quot;us&quot;, or &quot;our&quot;), you agree to be bound by these Terms of Service. If you do not agree, please do not use our services.
          </p>

          <h2>2. Services</h2>
          <p>
            Manifest Automations provides data infrastructure, automation consulting, and related software services. The specific deliverables and scope of work for any engagement will be governed by a separate Master Services Agreement (MSA) or Statement of Work (SOW).
          </p>

          <h2>3. Intellectual Property</h2>
          <p>
            Unless otherwise agreed in an MSA:
          </p>
          <ul>
            <li>Content on this website is owned by Manifest Automations.</li>
            <li>Code and automations built for you under a &quot;Work for Hire&quot; agreement become your property upon full payment.</li>
          </ul>

          <h2>4. Limitation of Liability</h2>
          <p>
            To the maximum extent permitted by law, Manifest Automations shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly.
          </p>

          <h2>5. Governing Law</h2>
          <p>
            These Terms shall be governed by and construed in accordance with the laws of the State of Delaware, without regard to its conflict of law principles.
          </p>

          <h2>6. Contact</h2>
          <p>
            Questions about these Terms? Contact us at <a href="mailto:hello@manifestautomations.com">hello@manifestautomations.com</a>.
          </p>
        </div>
      </main>

      <Footer />
    </div>
  );
}
