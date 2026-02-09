export default function CandidatesPage() {
  const candidates = [
    {
      id: "c1",
      name: "Alex Chen",
      role: "Senior Frontend Dev",
      status: "Recommended",
      score: 9,
      interviewDate: "2026-02-13",
      recordingUrl: "#",
      summary: "Strong technical skills in React/Next.js. Good cultural fit."
    },
    {
      id: "c2",
      name: "Sarah Jones",
      role: "Sales Representative",
      status: "Rejected",
      score: 4,
      interviewDate: "2026-02-13",
      recordingUrl: "#",
      summary: "Lacked closing experience. Struggled with objection handling scenario."
    },
    {
      id: "c3",
      name: "Mike Ross",
      role: "Legal Counsel",
      status: "Review",
      score: 7,
      interviewDate: "2026-02-12",
      recordingUrl: "#",
      summary: "Good knowledge but requested high salary. Needs human review."
    }
  ];

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900">Candidates</h1>
        <div className="flex gap-2">
          <button className="bg-white border border-gray-300 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-50">
            Filter
          </button>
          <button className="bg-white border border-gray-300 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-50">
            Export CSV
          </button>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <table className="w-full text-left text-sm text-gray-600">
          <thead className="bg-gray-50 text-gray-900">
            <tr>
              <th className="px-6 py-3 font-medium">Candidate</th>
              <th className="px-6 py-3 font-medium">Role</th>
              <th className="px-6 py-3 font-medium">Date</th>
              <th className="px-6 py-3 font-medium">AI Score</th>
              <th className="px-6 py-3 font-medium">Status</th>
              <th className="px-6 py-3 font-medium">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {candidates.map((candidate) => (
              <tr key={candidate.id} className="hover:bg-gray-50 group">
                <td className="px-6 py-4">
                  <div className="font-medium text-gray-900">{candidate.name}</div>
                  <div className="text-xs text-gray-500 truncate max-w-[200px]">{candidate.summary}</div>
                </td>
                <td className="px-6 py-4">{candidate.role}</td>
                <td className="px-6 py-4">{candidate.interviewDate}</td>
                <td className="px-6 py-4">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                    candidate.score >= 8 ? 'bg-green-100 text-green-800' : 
                    candidate.score >= 5 ? 'bg-yellow-100 text-yellow-800' : 'bg-red-100 text-red-800'
                  }`}>
                    {candidate.score}/10
                  </span>
                </td>
                <td className="px-6 py-4">
                  <span className={`px-2 py-1 rounded text-xs font-medium ${
                    candidate.status === 'Recommended' ? 'bg-green-50 text-green-700' :
                    candidate.status === 'Rejected' ? 'bg-red-50 text-red-700' : 'bg-blue-50 text-blue-700'
                  }`}>
                    {candidate.status}
                  </span>
                </td>
                <td className="px-6 py-4">
                  <a href="#" className="text-blue-600 hover:text-blue-800 font-medium">View Transcript</a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
