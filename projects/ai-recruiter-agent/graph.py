from typing import Annotated, Literal, TypedDict
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
from langgraph.graph import StateGraph, START, END
from langgraph.prebuilt import ToolNode
import os

# --- 1. State Definition ---
class AgentState(TypedDict):
    messages: list[HumanMessage | AIMessage | SystemMessage]
    next_step: Literal["interview", "score", "end"]
    candidate_data: dict

# --- 2. Tools ---
# In a real app, these would be LangChain tools wrapping Vapi/DB/etc.
def vapi_call_candidate(candidate_id: str, phone: str):
    """Initiates a Vapi call to the candidate."""
    return f"Called candidate {candidate_id} at {phone}"

def save_transcript(call_id: str, transcript: str):
    """Saves transcript to Supabase."""
    return "Transcript saved"

# --- 3. Nodes ---

def supervisor_node(state: AgentState):
    """Decides the next step based on state."""
    messages = state['messages']
    last_message = messages[-1] if messages else None
    
    # Logic to route
    if not last_message:
        return {"next_step": "interview"}
    
    return {"next_step": "end"}

def interview_node(state: AgentState):
    """Orchestrates the Vapi interview."""
    # This would trigger the Vapi Outbound Call
    return {"messages": [AIMessage(content="Interview initiated via Vapi")]}

def score_node(state: AgentState):
    """Scores the interview transcript using DeepSeek/Claude."""
    return {"messages": [AIMessage(content="Score: 8/10")]}

# --- 4. Graph Construction ---
workflow = StateGraph(AgentState)

workflow.add_node("supervisor", supervisor_node)
workflow.add_node("interviewer", interview_node)
workflow.add_node("scorer", score_node)

workflow.add_edge(START, "supervisor")

workflow.add_conditional_edges(
    "supervisor",
    lambda state: state["next_step"],
    {
        "interview": "interviewer",
        "score": "scorer",
        "end": END
    }
)

workflow.add_edge("interviewer", "supervisor")
workflow.add_edge("scorer", "supervisor")

app = workflow.compile()

if __name__ == "__main__":
    print("AI Recruiter Graph Compiled.")
