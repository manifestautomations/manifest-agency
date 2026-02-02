# User Stories & Acceptance Criteria (v1.0)

## 🔐 Epic: Authentication & Onboarding
**Goal:** Securely identify users and capture their kitchen profile.

### Story 1: Sign Up / Login
**As a** new user,  
**I want to** sign in with Apple or Google,  
**So that** I don't have to remember another password.

- [ ] "Sign in with Apple" button works.
- [ ] "Sign in with Google" button works.
- [ ] Account is created in Supabase `auth.users`.
- [ ] Profile entry is automatically created in `public.profiles`.

### Story 2: Dietary Preferences
**As a** user with allergies,  
**I want to** set my dietary restrictions (e.g., Vegan, Nut-Free),  
**So that** generated recipes don't kill me.

- [ ] User can select tags during onboarding.
- [ ] Tags are saved to `profiles.dietary_preferences`.
- [ ] Settings screen allows updating preferences later.

---

## 📦 Epic: Inventory Management
**Goal:** Maintain an accurate digital twin of the pantry.

### Story 3: Manual Add Item
**As a** user,  
**I want to** manually type in an item (e.g., "Milk"),  
**So that** I can track things without barcodes.

- [ ] "Add Item" form has: Name, Quantity, Unit, Expiry (Optional), Location (Fridge/Pantry).
- [ ] Item is saved to `pantry_items`.
- [ ] Success toast appears.

### Story 4: Barcode Lookup (Future v1.1)
*Note: Depending on API availability.*
**As a** user,  
**I want to** scan a barcode,  
**So that** the app fills in the details for me.

- [ ] Camera opens and detects barcode.
- [ ] App queries `public.items` (Global Master List).
- [ ] If found, pre-fill Name/Category.
- [ ] If not found, prompt user to enter Name (and contribute to DB).

### Story 5: Consume/Delete Item
**As a** user,  
**I want to** swipe to remove an item,  
**So that** my inventory stays current.

- [ ] Swipe Right: "Consumed" (Sets quantity to 0 or marks `is_consumed=true`).
- [ ] Swipe Left: "Delete" (Removes row entirely).

---

## 📸 Epic: Smart Scanning (The "Wow" Factor)
**Goal:** Import groceries with zero friction.

### Story 6: Receipt Scan
**As a** shopper,  
**I want to** take a photo of my grocery receipt,  
**So that** all 20 items are added at once.

- [ ] Camera captures high-res image.
- [ ] Image uploaded to Supabase Storage.
- [ ] AI Service (Edge Function) parses text.
- [ ] User sees a "Review" screen with extracted items.
- [ ] User confirms -> Batch insert into `pantry_items`.

---

## 👨‍🍳 Epic: Chef Mode (AI Recipes)
**Goal:** Reduce decision fatigue.

### Story 7: "What Can I Cook?"
**As a** hungry user,  
**I want to** see recipes using *only* what I have,  
**So that** I don't have to go to the store.

- [ ] "Generate" button sends current inventory + dietary prefs to LLM.
- [ ] LLM returns 3 recipe options (Name, Time, Missing Ingredients).
- [ ] Recipes respect dietary tags.

### Story 8: Save Recipe
**As a** user,  
**I want to** save a recipe I liked,  
**So that** I can cook it again.

- [ ] "Save" button adds to `public.recipes`.
- [ ] Saved recipes appear in "Cookbook" tab.
