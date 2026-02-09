import { NextResponse } from 'next/server';

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { message } = body;

    // Vapi sends a "function-call" message when the AI wants to execute a tool
    if (message.type === 'function-call') {
      const { name, parameters } = message.functionCall;
      console.log(`[Voice AI] Function Call: ${name}`, parameters);

      if (name === 'checkAvailability') {
        // Mock DB/Calendar call
        // In production: await cal.getAvailableSlots(parameters.date)
        const slots = ['10:00 AM', '2:00 PM', '4:30 PM'];
        
        return NextResponse.json({
          result: `Available slots are ${slots.join(', ')}.`
        });
      }

      if (name === 'bookAppointment') {
        // Mock Booking Logic
        console.log(`[Voice AI] Booking appointment for:`, parameters);
        return NextResponse.json({
          result: "Success. I have booked you for that time. You will receive a confirmation SMS shortly."
        });
      }
    }

    return NextResponse.json({});
  } catch (err) {
    console.error('Voice AI Error:', err);
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
  }
}
