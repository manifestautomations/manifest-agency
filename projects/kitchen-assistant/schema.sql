-- Kitchen Assistant v1.0 Schema
-- Supabase / PostgreSQL

-- 1. Profiles (Public User Data)
-- Links to Supabase Auth via triggers
create table public.profiles (
  id uuid references auth.users not null primary key,
  username text unique,
  avatar_url text,
  dietary_preferences jsonb default '[]'::jsonb, -- e.g. ["vegan", "nut-free"]
  household_size int default 1,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. Items (Global Master List)
-- Crowdsourced database of barcodes and products
create table public.items (
  barcode text primary key,
  name text not null,
  brand text,
  category text, -- "Dairy", "Produce", etc.
  default_unit text, -- "g", "ml", "count"
  image_url text,
  created_at timestamptz default now()
);

-- 3. Pantry Items (User Inventory)
create table public.pantry_items (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  barcode text references public.items(barcode),
  name text not null, -- Fallback if barcode missing
  quantity float not null default 1.0,
  unit text,
  expiry_date date,
  location text default 'Pantry', -- "Fridge", "Freezer"
  is_consumed boolean default false,
  added_at timestamptz default now()
);

-- 4. Recipes (Saved & Generated)
create table public.recipes (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  title text not null,
  description text,
  instructions jsonb not null, -- Array of step objects
  ingredients_matched jsonb, -- Snapshot of what inventory items were used
  is_favorite boolean default false,
  created_at timestamptz default now()
);

-- RLS Policies (Security)
alter table public.profiles enable row level security;
alter table public.items enable row level security;
alter table public.pantry_items enable row level security;
alter table public.recipes enable row level security;

-- Profiles: Public read, owner update
create policy "Public profiles are viewable by everyone." on public.profiles for select using (true);
create policy "Users can update own profile." on public.profiles for update using (auth.uid() = id);

-- Items: Public read, auth insert
create policy "Items are viewable by everyone." on public.items for select using (true);
create policy "Authenticated users can insert items." on public.items for insert with check (auth.role() = 'authenticated');

-- Pantry: Owner only
create policy "Users can only see own pantry." on public.pantry_items for select using (auth.uid() = user_id);
create policy "Users can insert own pantry." on public.pantry_items for insert with check (auth.uid() = user_id);
create policy "Users can update own pantry." on public.pantry_items for update using (auth.uid() = user_id);
create policy "Users can delete own pantry." on public.pantry_items for delete using (auth.uid() = user_id);

-- Recipes: Owner only
create policy "Users can only see own recipes." on public.recipes for select using (auth.uid() = user_id);
create policy "Users can insert own recipes." on public.recipes for insert with check (auth.uid() = user_id);
create policy "Users can update own recipes." on public.recipes for update using (auth.uid() = user_id);
create policy "Users can delete own recipes." on public.recipes for delete using (auth.uid() = user_id);

-- Triggers
-- Auto-create profile on signup
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.profiles (id, username)
  values (new.id, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
