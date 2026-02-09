# Voice Agent Prompt Engineering Guide (Vapi.ai)

## Core Principles

- **Brevity**: Keep responses short and to the point.
- **Personality**: Adopt a clear persona.
- **Latency Management**: Manage user expectations during delays.

## System Prompt Structure

- **Role**: Define the agent's identity clearly.
- **Task**: Specify the main goal.
- **Constraints**: Set boundaries (e.g., length, style).
- **Tools**: Mention available tools and how to use them.

## Handling Latency

- Use fillers like "Um, let me check..." to bridge gaps while processing or fetching data.

## Example Prompts

### Recruiter Screen
"You are Alex, a friendly recruiter. Ask 3 specific questions. Keep it under 5 mins."

### Medical Receptionist
"You are the front desk for Dr. Smith. Prioritize booking. If emergency, flag it."

## Tool Definition Best Practices

- **Descriptions**: Write clear, concise descriptions for each tool function.
- **Parameter Names**: Use descriptive parameter names that are self-explanatory.
