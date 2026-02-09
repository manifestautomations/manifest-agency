import { NextResponse } from 'next/server';

// Type definition for the request body
interface AgentInvokeRequest {
  task: string;
  model?: string;
  context?: Record<string, unknown>;
}

export async function POST(req: Request) {
  try {
    // 1. Validate Auth (Basic check for demo purposes)
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body: AgentInvokeRequest = await req.json();
    const { task, model, context } = body;

    if (!task) {
      return NextResponse.json({ error: 'Task is required' }, { status: 400 });
    }

    // 2. Construct the payload for Clawdbot Gateway
    // We use the 'sessions_spawn' tool to run a task in a background session
    const gatewayPayload = {
      tool: 'sessions_spawn',
      action: 'run',
      sessionKey: 'main', // Or generate a unique session ID per user/task
      args: {
        task: task,
        model: model || 'claude-3-7-sonnet-20260224',
        // We can pass context as part of the task string or via a specialized prompt
        // For simple tasks, appending context is easiest
        prompt: context ? `Context: ${JSON.stringify(context)}\n\nTask: ${task}` : task
      }
    };

    // 3. Call the Clawdbot Gateway /tools/invoke endpoint
    // In production, CLAWDBOT_GATEWAY_URL would be an internal private URL
    const gatewayUrl = process.env.CLAWDBOT_GATEWAY_URL || 'http://localhost:18789';
    const gatewayToken = process.env.CLAWDBOT_GATEWAY_TOKEN;

    if (!gatewayToken) {
      console.warn('CLAWDBOT_GATEWAY_TOKEN not set. Mocking response.');
      // Mock response for development if no token
      return NextResponse.json({
        ok: true,
        mock: true,
        message: 'Agent task queued (Mock)',
        taskId: 'mock-task-' + Date.now()
      });
    }

    const response = await fetch(`${gatewayUrl}/tools/invoke`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${gatewayToken}`
      },
      body: JSON.stringify(gatewayPayload)
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Clawdbot Gateway Error:', errorText);
      return NextResponse.json({ error: 'Failed to invoke agent', details: errorText }, { status: 502 });
    }

    const data = await response.json();

    // 4. Return success to the UI
    return NextResponse.json({
      ok: true,
      result: data.result, // Contains the output from sessions_spawn (e.g., initial message)
      taskId: data.result?.sessionId // If sessions_spawn returns the new session ID
    });

  } catch (error: unknown) {
    console.error('Agent Invoke Error:', error);
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
  }
}
