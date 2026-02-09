import VapiDemo from '../../../components/VapiDemo';

export default function NewJobPage() {
  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Create New Job</h1>
        <p className="text-gray-500 mt-2">Define the role and let our AI Recruiter handle the first round.</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Form */}
        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
          <form className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Job Title</label>
              <input type="text" className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" placeholder="e.g. Senior Frontend Developer" />
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Department</label>
              <select className="w-full px-4 py-2 border border-gray-300 rounded-lg">
                <option>Engineering</option>
                <option>Sales</option>
                <option>Marketing</option>
                <option>Legal</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Job Description (Paste)</label>
              <textarea className="w-full px-4 py-2 border border-gray-300 rounded-lg h-32" placeholder="Paste the full JD here..."></textarea>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Interview Questions (AI Generated)</label>
              <div className="space-y-2 bg-gray-50 p-4 rounded-lg border border-gray-200">
                <div className="flex items-start gap-2">
                  <span className="bg-blue-100 text-blue-800 text-xs font-medium px-2 py-0.5 rounded">1</span>
                  <p className="text-sm text-gray-600">Tell me about a time you had to optimize a React application for performance.</p>
                </div>
                <div className="flex items-start gap-2">
                  <span className="bg-blue-100 text-blue-800 text-xs font-medium px-2 py-0.5 rounded">2</span>
                  <p className="text-sm text-gray-600">How do you handle disagreements with designers about feasibility?</p>
                </div>
              </div>
            </div>

            <button type="button" className="w-full bg-blue-600 text-white py-3 rounded-lg font-semibold hover:bg-blue-700">
              Deploy AI Interviewer
            </button>
          </form>
        </div>

        {/* Preview */}
        <div className="space-y-6">
          <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
            <h3 className="text-lg font-semibold mb-4">Test the Agent</h3>
            <VapiDemo />
          </div>

          <div className="bg-blue-50 p-6 rounded-xl border border-blue-100">
            <h3 className="text-blue-900 font-semibold mb-2">How it works</h3>
            <ul className="list-disc list-inside text-sm text-blue-800 space-y-2">
              <li>Candidates receive a unique link.</li>
              <li>The AI conducts a 10-15 min voice interview.</li>
              <li>You get a transcript and a 1-10 score.</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
