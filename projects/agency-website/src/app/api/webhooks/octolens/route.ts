import { NextResponse } from 'next/server';
import crypto from 'crypto';

export async function POST(req: Request) {
  try {
    // 1. Get Raw Body for Verification
    const rawBody = await req.text();
    
    // 2. Verify Signature (Mock logic until Octolens docs confirmed)
    // In production, you would check x-octolens-signature against process.env.OCTOLENS_WEBHOOK_SECRET
    /*
    const signature = req.headers.get('x-octolens-signature');
    const expected = crypto
      .createHmac('sha256', process.env.OCTOLENS_WEBHOOK_SECRET!)
      .update(rawBody)
      .digest('hex');
      
    if (signature !== expected) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    */

    // 3. Parse Payload
    const data = JSON.parse(rawBody);
    console.log('[Octolens Webhook] Received lead:', data);

    // 4. TODO: Save to database or queue for processing
    // await db.leads.create({ ...data });

    return NextResponse.json({ received: true });
  } catch (err) {
    console.error('Webhook Error:', err);
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
  }
}
