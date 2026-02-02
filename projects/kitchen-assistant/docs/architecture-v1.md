# Kitchen Assistant v1.0 - Architecture & Tech Stack

## 🏗️ Core Tech Stack (The "Speed Run" Stack)
*Optimized for rapid development, low cost, and scalability.*

### Mobile App (Client)
- **Framework:** React Native (via **Expo SDK 52+**)
  - *Why:* One codebase for iOS/Android, instant OTA updates, massive plugin ecosystem.
- **Language:** TypeScript (Strict mode)
- **State Management:** TanStack Query (React Query)
  - *Why:* Handles caching, optimistic updates, and offline syncing logic perfectly.
- **UI Library:** Tamagui or NativeWind (Tailwind for RN)
  - *Why:* Fast styling, consistent design tokens.
- **Local Storage:** MMKV
  - *Why:* Fastest key-value storage for persistence.

### Backend & Database (Serverless)
- **Platform:** **Supabase**
  - *Why:* Postgres is king. Auth, Storage, and Realtime are built-in. Zero infrastructure to manage.
- **Database:** PostgreSQL 17+
- **Auth:** Supabase Auth (Apple, Google, Email/Magic Link)
- **Storage:** Supabase Storage (Receipt images, user avatars)
- **Edge Functions:** Deno/Node.js (for complex AI orchestration)

### AI & Intelligence
- **Vision (Receipt Scanning):** GPT-4o-mini or Gemini Flash (via API)
  - *Why:* Cheap, fast, multimodal.
- **Recipe Generation:** Claude 3.5 Haiku or GPT-4o-mini
  - *Why:* Low latency, good creative reasoning.
- **Search:** Postgres `pgvector` (Supabase)
  - *Why:* Semantic search for "Find me something spicy with chicken".

---

## 💾 Database Schema (v1 Draft)

### `profiles` (Public User Data)
- `id` (uuid, PK, ref auth.users)
- `username` (text)
- `avatar_url` (text)
- `dietary_preferences` (jsonb) -> `["vegan", "nut-free"]`
- `household_size` (int)

### `items` (Global Master List)
*Crowdsourced database of barcodes and products.*
- `barcode` (text, PK)
- `name` (text)
- `brand` (text)
- `category` (text) -> "Dairy", "Produce", etc.
- `default_unit` (text) -> "g", "ml", "count"

### `pantry_items` (User Inventory)
*What the user actually has.*
- `id` (uuid, PK)
- `user_id` (uuid, ref profiles.id)
- `barcode` (text, ref items.barcode, nullable)
- `name` (text) -> "Leftover Lasagna"
- `quantity` (float)
- `unit` (text)
- `expiry_date` (date)
- `location` (text) -> "Fridge", "Freezer", "Pantry"
- `added_at` (timestamptz)

### `recipes` (Saved & Generated)
- `id` (uuid, PK)
- `user_id` (uuid, ref profiles.id)
- `title` (text)
- `description` (text)
- `instructions` (jsonb) -> Step-by-step array
- `ingredients_matched` (jsonb) -> Snapshot of what was used
- `is_favorite` (bool)

---

## 🧠 AI Workflows

### 1. Receipt Scanning (The "Magic" Moment)
1. User snaps photo -> Upload to Supabase Storage.
2. Edge Function triggers -> Sends URL to GPT-4o-mini.
3. Prompt: *"Extract items, quantities, and likely expiry dates from this receipt JSON."*
4. Response -> Parsed & inserted into `pantry_items`.

### 2. "Chef Mode" (RAG Pipeline)
1. User clicks "What can I cook?".
2. Client sends current inventory (`pantry_items`) to Edge Function.
3. System prompts LLM: *"You are a chef. Using ONLY these ingredients: [List], suggest 3 recipes. Assume user has basic staples (oil, salt)."*
4. Output -> JSON response to UI.

---

## 🔒 Security & Privacy
- **RLS (Row Level Security):** Enabled on ALL tables. Users can only see/edit their own data.
- **Encryption:** At rest (Supabase default) and in transit (SSL).
- **Data Minimization:** We only store what we need. Receipt images deleted after processing (optional setting).
