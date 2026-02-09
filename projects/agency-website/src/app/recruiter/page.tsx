import Link from 'next/link';

export default function RecruiterDashboard() {
  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <Link 
          href="/recruiter/new-job" 
          className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
        >
          + New Job
        </Link>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
          <h3 className="text-gray-500 text-sm font-medium">Active Jobs</h3>
          <p className="text-3xl font-bold text-gray-900 mt-2">3</p>
        </div>
        <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
          <h3 className="text-gray-500 text-sm font-medium">Interviews Conducted (Week)</h3>
          <p className="text-3xl font-bold text-gray-900 mt-2">124</p>
        </div>
        <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
          <h3 className="text-gray-500 text-sm font-medium">Qualified Candidates</h3>
          <p className="text-3xl font-bold text-gray-900 mt-2 text-green-600">18</p>
        </div>
      </div>

      {/* Recent Activity */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-100">
          <h3 className="font-semibold text-gray-900">Recent AI Interviews</h3>
        </div>
        <table className="w-full text-left text-sm text-gray-600">
          <thead className="bg-gray-50 text-gray-900">
            <tr>
              <th className="px-6 py-3 font-medium">Candidate</th>
              <th className="px-6 py-3 font-medium">Role</th>
              <th className="px-6 py-3 font-medium">Score</th>
              <th className="px-6 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {[
              { name: "Alex Chen", role: "Senior Frontend Dev", score: 9, status: "Recommended" },
              { name: "Sarah Jones", role: "Sales Rep", score: 4, status: "Rejected" },
              { name: "Mike Ross", role: "Legal Counsel", score: 7, status: "Review" },
            ].map((row, i) => (
              <tr key={i} className="hover:bg-gray-50">
                <td className="px-6 py-4 font-medium text-gray-900">{row.name}</td>
                <td className="px-6 py-4">{row.role}</td>
                <td className="px-6 py-4">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                    row.score >= 8 ? 'bg-green-100 text-green-800' : 
                    row.score >= 5 ? 'bg-yellow-100 text-yellow-800' : 'bg-red-100 text-red-800'
                  }`}>
                    {row.score}/10
                  </span>
                </td>
                <td className="px-6 py-4">{row.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
