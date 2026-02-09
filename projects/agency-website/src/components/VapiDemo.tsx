'use client';

import { useState, useEffect } from 'react';
// import Vapi from '@vapi-ai/web'; // Uncomment when package is installed

export default function VapiDemo() {
  const [status, setStatus] = useState<'idle' | 'connecting' | 'connected'>('idle');
  const [vapi, setVapi] = useState<unknown>(null);

  useEffect(() => {
    // Dynamic import to avoid SSR issues if package was installed
    import('@vapi-ai/web').then((module) => {
        const Vapi = module.default;
        const vapiInstance = new Vapi(process.env.NEXT_PUBLIC_VAPI_PUBLIC_KEY || '');
        setVapi(vapiInstance);

        vapiInstance.on('call-start', () => setStatus('connected'));
        vapiInstance.on('call-end', () => setStatus('idle'));
        vapiInstance.on('error', (e: unknown) => console.error(e));
    }).catch(() => {
        console.log("Vapi SDK not found - mocking for UI demo");
    });
  }, []);

  const startCall = () => {
    if (!vapi) {
        alert("Vapi SDK not configured. This is a UI demo.");
        return;
    }
    setStatus('connecting');
    // Replace with your Assistant ID
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (vapi as any).start('YOUR_ASSISTANT_ID');
  };

  const stopCall = () => {
    if (vapi) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (vapi as any).stop();
    }
    setStatus('idle');
  };

  return (
    <div className="flex flex-col items-center justify-center p-8 bg-gray-900 rounded-xl text-white">
      <div className={`w-24 h-24 rounded-full flex items-center justify-center mb-6 transition-all duration-500 ${
        status === 'connected' ? 'bg-green-500 shadow-[0_0_30px_rgba(34,197,94,0.5)] animate-pulse' : 
        status === 'connecting' ? 'bg-yellow-500 animate-bounce' : 'bg-gray-700'
      }`}>
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-10 h-10">
          <path strokeLinecap="round" strokeLinejoin="round" d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z" />
        </svg>
      </div>

      <h2 className="text-xl font-bold mb-2">
        {status === 'idle' ? 'Start Interview' : 
         status === 'connecting' ? 'Connecting...' : 'Interview in Progress'}
      </h2>
      
      <p className="text-gray-400 text-sm mb-6 text-center max-w-xs">
        {status === 'idle' ? 'Speak with our AI Recruiter to test the candidate experience.' : 
         'Listening... (You can speak naturally)'}
      </p>

      {status === 'idle' ? (
        <button 
          onClick={startCall}
          className="bg-white text-gray-900 px-6 py-3 rounded-full font-semibold hover:bg-gray-200 transition-colors"
        >
          Start Call
        </button>
      ) : (
        <button 
          onClick={stopCall}
          className="bg-red-500 text-white px-6 py-3 rounded-full font-semibold hover:bg-red-600 transition-colors"
        >
          End Call
        </button>
      )}
    </div>
  );
}
