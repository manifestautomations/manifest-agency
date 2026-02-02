import { NextResponse } from 'next/server';

export async function POST(req: Request) {
  try {
    const body = await req.json();
    console.log('[Leadsie Webhook] Received event:', body);

    // Payload structure based on design:
    // { user: "client_id", connectionAssets: [{ id: "act_123", type: "Ad Account" }] }

    const { user, connectionAssets } = body;

    if (!user || !connectionAssets) {
        return NextResponse.json({ error: 'Invalid payload' }, { status: 400 });
    }

    // TODO: 
    // 1. Verify webhook signature (if Leadsie supports it)
    // 2. Lookup client in DB using 'user' (client_id)
    // 3. For each asset, trigger Airbyte source creation
    
    // Mock success for now
    console.log(`[Onboarding] Provisioning assets for Client ${user}:`, connectionAssets);

    return NextResponse.json({ received: true });
  } catch (err) {
    console.error('Webhook Error:', err);
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
  }
}
