import { NextResponse } from 'next/server';

export async function GET(req: Request) {
  const authHeader = req.headers.get('authorization');
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return new Response('Unauthorized', {
      status: 401,
    });
  }

  console.log('[Cron] Syncing leads from external sources...');
  
  // Placeholder: Sync logic (e.g., fetch from Apollo, update DB)
  // await syncLeads();

  return NextResponse.json({ synced: 0, status: 'success' });
}
