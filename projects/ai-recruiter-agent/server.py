from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, Dict, Any
import uvicorn
from graph import app as graph_app

# Initialize FastAPI
app = FastAPI(title="AI Recruiter Agent", version="1.0.0")

class AgentRequest(BaseModel):
    task: string
    model: Optional[str] = "claude-3-7-sonnet-20260224"
    context: Optional[Dict[str, Any]] = None

class AgentResponse(BaseModel):
    status: str
    job_id: str
    message: str

def run_agent_background(task: str, context: dict):
    """
    Executes the LangGraph workflow in the background.
    In a real system, this would update a DB or send a webhook upon completion.
    """
    try:
        print(f"Starting task: {task}")
        # Initial state for the graph
        initial_state = {
            "messages": [], 
            "candidate_data": context or {},
            "next_step": "supervisor"
        }
        
        # Run the graph
        # Note: In production, use astream or invoke with a thread_id for persistence
        result = graph_app.invoke(initial_state)
        print(f"Task completed. Result state: {result}")
        
    except Exception as e:
        print(f"Error running agent: {e}")

@app.post("/invoke", response_model=AgentResponse)
async def invoke_agent(request: AgentRequest, background_tasks: BackgroundTasks):
    """
    Endpoint to trigger the AI Recruiter Agent.
    This mimics the Clawdbot /tools/invoke interface pattern for consistency.
    """
    job_id = f"job-{uuid.uuid4()}"
    
    # Enqueue the task
    background_tasks.add_task(
        run_agent_background, 
        request.task, 
        request.context
    )
    
    return AgentResponse(
        status="queued",
        job_id=job_id,
        message="Agent task started successfully"
    )

@app.get("/health")
def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
