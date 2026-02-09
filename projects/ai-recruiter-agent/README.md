# AI Recruiter Agent (Backend)

This is the backend orchestration layer for the AI Recruiter product. It uses **LangGraph** to manage the state of the interview process.

## Architecture

- **`graph.py`**: The main entry point defining the state machine.
- **Supervisor Node**: Decides whether to Interview, Score, or Sleep.
- **Tools**: Wrappers around Vapi.ai (Voice) and Supabase (DB).

## Setup

1. `python -m venv venv`
2. `source venv/bin/activate`
3. `pip install -r requirements.txt`
4. `python graph.py`

## Integration

This service exposes a webhook that the **Next.js Dashboard** calls via `POST /api/agents/invoke`.
