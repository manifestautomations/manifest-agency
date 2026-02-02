-- Seed Data for Kitchen Assistant
-- Run this after applying schema.sql

-- 1. Insert Categories (Implicit in items table, but good to check)
-- No explicit table, just strings in items

-- 2. Seed Common Items (Global Master List)
insert into public.items (barcode, name, brand, category, default_unit, image_url) values
-- Dairy
('0001', 'Whole Milk', 'Generic', 'Dairy', 'L', 'https://example.com/milk.png'),
('0002', 'Butter (Salted)', 'Generic', 'Dairy', 'g', 'https://example.com/butter.png'),
('0003', 'Cheddar Cheese', 'Generic', 'Dairy', 'g', 'https://example.com/cheese.png'),
('0004', 'Greek Yogurt', 'Chobani', 'Dairy', 'g', 'https://example.com/yogurt.png'),
('0005', 'Heavy Cream', 'Generic', 'Dairy', 'ml', 'https://example.com/cream.png'),

-- Produce
('0101', 'Bananas', 'Generic', 'Produce', 'count', 'https://example.com/banana.png'),
('0102', 'Avocado', 'Generic', 'Produce', 'count', 'https://example.com/avocado.png'),
('0103', 'Red Onion', 'Generic', 'Produce', 'count', 'https://example.com/onion.png'),
('0104', 'Garlic', 'Generic', 'Produce', 'head', 'https://example.com/garlic.png'),
('0105', 'Spinach', 'Generic', 'Produce', 'g', 'https://example.com/spinach.png'),

-- Pantry Staples
('0201', 'Olive Oil (Extra Virgin)', 'Generic', 'Pantry', 'ml', 'https://example.com/oliveoil.png'),
('0202', 'Pasta (Spaghetti)', 'Barilla', 'Pantry', 'g', 'https://example.com/pasta.png'),
('0203', 'Rice (Basmati)', 'Generic', 'Pantry', 'kg', 'https://example.com/rice.png'),
-- Note: 'Rao''s' is the brand "Rao's" with the single quote escaped per SQL string literal rules.
('0204', 'Tomato Sauce', 'Rao''s', 'Pantry', 'g', 'https://example.com/sauce.png'),
('0205', 'Black Beans (Canned)', 'Goya', 'Pantry', 'can', 'https://example.com/beans.png'),

-- Spices
('0301', 'Salt (Kosher)', 'Diamond Crystal', 'Spices', 'g', 'https://example.com/salt.png'),
('0302', 'Black Pepper', 'McCormick', 'Spices', 'g', 'https://example.com/pepper.png'),
('0303', 'Cumin', 'Generic', 'Spices', 'g', 'https://example.com/cumin.png'),
('0304', 'Paprika (Smoked)', 'Generic', 'Spices', 'g', 'https://example.com/paprika.png')

on conflict (barcode) do nothing;

-- 3. Seed Sample User (Optional, requires Auth ID)
-- insert into public.profiles (id, username) values ('UUID_HERE', 'demo_chef');
