import { NextResponse } from 'next/server';

export async function GET(req: Request) {
  const authHeader = req.headers.get('authorization');
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return new Response('Unauthorized', {
      status: 401,
    });
  }

  // Logic to query DB or just log to prevent cold starts
  console.log('[Cron] Keep-alive triggered at', new Date().toISOString());

  return NextResponse.json({ ok: true });
}
