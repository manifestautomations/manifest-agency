# Game Studio Tech Stack (Draft)

**Goal:** Build "Living Worlds" where NPCs have agency and memory.
**Engine:** Godot 4 (Open Source, Python-like GDScript).

## 1. The "Brain" (LLM Integration)
Instead of hardcoded dialogue trees, we use LLMs.

### Option A: Local (Privacy/Offline)
- **Tool:** `Godot LLM` plugin.
- **Model:** Llama 3 (8B) quantized.
- **Hardware:** Runs on user's GPU.
- **Use Case:** Companion NPCs, dynamic banter.

### Option B: Cloud (Intelligence)
- **Tool:** HTTPRequest node -> Vapi.ai / OpenAI.
- **Model:** DeepSeek R1 (Reasoning).
- **Use Case:** Dungeon Master AI, Quest Generation, overarching plot logic.

## 2. The "Body" (Behavior)
- **Tool:** `Godot RL Agents`.
- **Method:** Reinforcement Learning (PPO).
- **Use Case:** Combat AI that learns from the player. If the player spams fireballs, the AI learns to equip fire resistance.

## 3. The "Voice" (TTS)
- **Tool:** ElevenLabs API (or local Coqui TTS).
- **Integration:** Stream audio bytes directly to `AudioStreamPlayer`.
- **Latency:** Critical (<300ms).

## 4. The "Memory" (State)
- **Tool:** Graphiti (Knowledge Graph).
- **Structure:**
    - `(Player)-[:KILLED]->(NPC_Brother)`
    - `(NPC_Sister)-[:HATES]->(Player)`
- **Impact:** Actions have permanent, logical consequences.

## Prototype Idea: "The Innkeeper"
A simple scene where you talk to an Innkeeper.
- **Goal:** Rent a room.
- **Twist:** You have no money. You must persuade him (LLM) or steal the key (Game Mechanic).
- **Stack:** Godot + DeepSeek R1 API.
