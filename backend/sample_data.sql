-- Sample data for White-Label Cooking App
-- Run this after creating the database schema

-- Insert sample chef
INSERT INTO chefs (id, name, bio, app_name, avatar_url, logo_url, theme_config, social_links) VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    'Chef Maria Rodriguez',
    'Award-winning chef specializing in Mediterranean and Latin fusion cuisine. With over 15 years of experience in top restaurants around the world, Chef Maria brings authentic flavors and modern techniques to home cooking.',
    'Maria''s Kitchen',
    'https://images.unsplash.com/photo-1583394293214-28ded15ee548?w=400',
    'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=200',
    '{
        "primary_color": "#E74C3C",
        "secondary_color": "#F39C12",
        "accent_color": "#27AE60",
        "background_color": "#FFFFFF",
        "text_color": "#2C3E50",
        "font_family": "Inter"
    }',
    '{
        "instagram": "https://instagram.com/chefmaria",
        "website": "https://mariaskitchen.com"
    }'
);

-- Insert sample recipes
INSERT INTO recipes (id, title, description, chef_id, cuisine, category, difficulty, prep_time_minutes, cook_time_minutes, servings, instructions, images, tags, is_featured) VALUES 

-- Recipe 1: Mediterranean Pasta
('550e8400-e29b-41d4-a716-446655440001',
'Mediterranean Pasta with Sun-Dried Tomatoes',
'A vibrant and flavorful pasta dish featuring sun-dried tomatoes, fresh basil, and creamy feta cheese. This Mediterranean-inspired recipe brings together the best of Italian and Greek flavors in one delicious meal.',
'550e8400-e29b-41d4-a716-446655440000',
'Mediterranean',
'Dinner',
2,
15,
20,
4,
ARRAY[
    'Bring a large pot of salted water to boil and cook pasta according to package directions until al dente.',
    'While pasta cooks, heat olive oil in a large skillet over medium heat.',
    'Add minced garlic and cook for 1 minute until fragrant.',
    'Add sun-dried tomatoes and cook for 2-3 minutes.',
    'Add cherry tomatoes and cook until they start to burst, about 5 minutes.',
    'Season with salt, pepper, and red pepper flakes.',
    'Drain pasta, reserving 1 cup of pasta water.',
    'Add pasta to the skillet with vegetables and toss to combine.',
    'Add pasta water gradually until desired consistency is reached.',
    'Remove from heat and stir in fresh basil and feta cheese.',
    'Serve immediately with extra feta and basil on top.'
],
ARRAY[
    'https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=800',
    'https://images.unsplash.com/photo-1563379091339-03246963d96c?w=800'
],
ARRAY['pasta', 'mediterranean', 'vegetarian', 'quick', 'easy'],
true),

-- Recipe 2: Spicy Chicken Tacos
('550e8400-e29b-41d4-a716-446655440002',
'Spicy Chicken Tacos with Avocado Crema',
'Tender, spiced chicken served in warm tortillas with a cooling avocado crema. These tacos pack a flavorful punch and are perfect for a weeknight dinner or casual entertaining.',
'550e8400-e29b-41d4-a716-446655440000',
'Mexican',
'Dinner',
3,
20,
25,
6,
ARRAY[
    'Season chicken thighs with cumin, chili powder, paprika, salt, and pepper.',
    'Heat oil in a large skillet over medium-high heat.',
    'Cook chicken for 6-7 minutes per side until cooked through and internal temperature reaches 165°F.',
    'Let chicken rest for 5 minutes, then slice into strips.',
    'For avocado crema: mash avocados with lime juice, sour cream, and salt until smooth.',
    'Warm tortillas in a dry skillet or microwave.',
    'Assemble tacos with chicken, avocado crema, diced onion, and cilantro.',
    'Serve with lime wedges and hot sauce on the side.'
],
ARRAY[
    'https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=800',
    'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=800'
],
ARRAY['tacos', 'mexican', 'spicy', 'chicken', 'avocado'],
true),

-- Recipe 3: Classic Caesar Salad
('550e8400-e29b-41d4-a716-446655440003',
'Classic Caesar Salad with Homemade Croutons',
'The ultimate Caesar salad with crisp romaine lettuce, homemade croutons, fresh parmesan, and a creamy garlic dressing made from scratch.',
'550e8400-e29b-41d4-a716-446655440000',
'American',
'Salad',
2,
25,
10,
4,
ARRAY[
    'Preheat oven to 375°F for croutons.',
    'Cut bread into 1-inch cubes and toss with olive oil, salt, and garlic powder.',
    'Bake croutons for 10-12 minutes until golden brown.',
    'For dressing: whisk together mayonnaise, lemon juice, Worcestershire sauce, Dijon mustard, minced garlic, and anchovy paste.',
    'Gradually whisk in olive oil until smooth.',
    'Season dressing with salt and pepper to taste.',
    'Wash and dry romaine lettuce, then chop into bite-sized pieces.',
    'In a large bowl, toss lettuce with dressing until well coated.',
    'Add croutons and half the parmesan cheese, toss gently.',
    'Serve immediately topped with remaining parmesan and black pepper.'
],
ARRAY[
    'https://images.unsplash.com/photo-1546793665-c74683f339c1?w=800'
],
ARRAY['salad', 'caesar', 'classic', 'vegetarian', 'side'],
false),

-- Recipe 4: Chocolate Chip Cookies
('550e8400-e29b-41d4-a716-446655440004',
'Perfect Chocolate Chip Cookies',
'Soft, chewy chocolate chip cookies with crispy edges and gooey centers. This foolproof recipe delivers bakery-quality cookies every time.',
'550e8400-e29b-41d4-a716-446655440000',
'American',
'Dessert',
1,
15,
12,
24,
ARRAY[
    'Preheat oven to 375°F and line baking sheets with parchment paper.',
    'In a bowl, whisk together flour, baking soda, and salt.',
    'In a large bowl, cream together softened butter and both sugars until light and fluffy.',
    'Beat in eggs one at a time, then add vanilla extract.',
    'Gradually mix in the flour mixture until just combined.',
    'Fold in chocolate chips.',
    'Drop rounded tablespoons of dough onto prepared baking sheets, spacing 2 inches apart.',
    'Bake for 9-11 minutes until edges are golden brown but centers still look slightly underbaked.',
    'Let cool on baking sheet for 5 minutes before transferring to a wire rack.',
    'Store in an airtight container for up to one week.'
],
ARRAY[
    'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=800',
    'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=800'
],
ARRAY['cookies', 'dessert', 'chocolate', 'baking', 'sweet'],
true),

-- Recipe 5: Thai Green Curry
('550e8400-e29b-41d4-a716-446655440005',
'Authentic Thai Green Curry with Chicken',
'Aromatic and spicy Thai green curry with tender chicken, vegetables, and fresh herbs in a rich coconut milk base. A restaurant-quality dish you can make at home.',
'550e8400-e29b-41d4-a716-446655440000',
'Thai',
'Dinner',
4,
30,
25,
4,
ARRAY[
    'Cut chicken into bite-sized pieces and season with salt.',
    'Heat oil in a large pot or wok over medium-high heat.',
    'Add green curry paste and cook for 1-2 minutes until fragrant.',
    'Add thick part of coconut milk and stir to combine with curry paste.',
    'Add chicken and cook for 5-6 minutes until nearly cooked through.',
    'Add remaining coconut milk, fish sauce, and palm sugar.',
    'Bring to a gentle simmer and add bell peppers and eggplant.',
    'Cook for 8-10 minutes until vegetables are tender.',
    'Stir in Thai basil leaves and lime juice.',
    'Taste and adjust seasoning with more fish sauce or lime juice as needed.',
    'Serve hot over jasmine rice, garnished with extra basil and sliced chilies.'
],
ARRAY[
    'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=800'
],
ARRAY['thai', 'curry', 'spicy', 'chicken', 'coconut', 'asian'],
false);

-- Insert ingredients for each recipe
-- Mediterranean Pasta ingredients
INSERT INTO ingredients (recipe_id, name, amount, unit, notes, "order") VALUES
('550e8400-e29b-41d4-a716-446655440001', 'Penne pasta', 12, 'oz', '', 1),
('550e8400-e29b-41d4-a716-446655440001', 'Olive oil', 3, 'tbsp', 'extra virgin', 2),
('550e8400-e29b-41d4-a716-446655440001', 'Garlic', 4, 'cloves', 'minced', 3),
('550e8400-e29b-41d4-a716-446655440001', 'Sun-dried tomatoes', 0.5, 'cup', 'chopped', 4),
('550e8400-e29b-41d4-a716-446655440001', 'Cherry tomatoes', 1, 'cup', 'halved', 5),
('550e8400-e29b-41d4-a716-446655440001', 'Fresh basil', 0.25, 'cup', 'chopped', 6),
('550e8400-e29b-41d4-a716-446655440001', 'Feta cheese', 4, 'oz', 'crumbled', 7),
('550e8400-e29b-41d4-a716-446655440001', 'Red pepper flakes', 0.25, 'tsp', '', 8),
('550e8400-e29b-41d4-a716-446655440001', 'Salt', 1, 'tsp', 'to taste', 9),
('550e8400-e29b-41d4-a716-446655440001', 'Black pepper', 0.5, 'tsp', 'freshly ground', 10),

-- Spicy Chicken Tacos ingredients
('550e8400-e29b-41d4-a716-446655440002', 'Chicken thighs', 2, 'lbs', 'boneless, skinless', 1),
('550e8400-e29b-41d4-a716-446655440002', 'Cumin', 2, 'tsp', 'ground', 2),
('550e8400-e29b-41d4-a716-446655440002', 'Chili powder', 2, 'tsp', '', 3),
('550e8400-e29b-41d4-a716-446655440002', 'Paprika', 1, 'tsp', '', 4),
('550e8400-e29b-41d4-a716-446655440002', 'Vegetable oil', 2, 'tbsp', '', 5),
('550e8400-e29b-41d4-a716-446655440002', 'Corn tortillas', 12, 'pieces', 'small', 6),
('550e8400-e29b-41d4-a716-446655440002', 'Avocados', 2, 'pieces', 'ripe', 7),
('550e8400-e29b-41d4-a716-446655440002', 'Lime juice', 2, 'tbsp', 'fresh', 8),
('550e8400-e29b-41d4-a716-446655440002', 'Sour cream', 0.25, 'cup', '', 9),
('550e8400-e29b-41d4-a716-446655440002', 'White onion', 0.5, 'cup', 'diced', 10),
('550e8400-e29b-41d4-a716-446655440002', 'Cilantro', 0.25, 'cup', 'chopped', 11),
('550e8400-e29b-41d4-a716-446655440002', 'Salt', 1, 'tsp', '', 12),
('550e8400-e29b-41d4-a716-446655440002', 'Black pepper', 0.5, 'tsp', '', 13),

-- Caesar Salad ingredients
('550e8400-e29b-41d4-a716-446655440003', 'Romaine lettuce', 2, 'heads', 'large', 1),
('550e8400-e29b-41d4-a716-446655440003', 'Bread', 4, 'slices', 'day-old, for croutons', 2),
('550e8400-e29b-41d4-a716-446655440003', 'Parmesan cheese', 0.75, 'cup', 'freshly grated', 3),
('550e8400-e29b-41d4-a716-446655440003', 'Mayonnaise', 0.5, 'cup', '', 4),
('550e8400-e29b-41d4-a716-446655440003', 'Lemon juice', 2, 'tbsp', 'fresh', 5),
('550e8400-e29b-41d4-a716-446655440003', 'Worcestershire sauce', 1, 'tsp', '', 6),
('550e8400-e29b-41d4-a716-446655440003', 'Dijon mustard', 1, 'tsp', '', 7),
('550e8400-e29b-41d4-a716-446655440003', 'Garlic', 2, 'cloves', 'minced', 8),
('550e8400-e29b-41d4-a716-446655440003', 'Anchovy paste', 1, 'tsp', 'optional', 9),
('550e8400-e29b-41d4-a716-446655440003', 'Olive oil', 3, 'tbsp', 'for croutons and dressing', 10),

-- Chocolate Chip Cookies ingredients
('550e8400-e29b-41d4-a716-446655440004', 'All-purpose flour', 2.25, 'cups', '', 1),
('550e8400-e29b-41d4-a716-446655440004', 'Baking soda', 1, 'tsp', '', 2),
('550e8400-e29b-41d4-a716-446655440004', 'Salt', 1, 'tsp', '', 3),
('550e8400-e29b-41d4-a716-446655440004', 'Butter', 1, 'cup', 'softened', 4),
('550e8400-e29b-41d4-a716-446655440004', 'Brown sugar', 0.75, 'cup', 'packed', 5),
('550e8400-e29b-41d4-a716-446655440004', 'Granulated sugar', 0.25, 'cup', '', 6),
('550e8400-e29b-41d4-a716-446655440004', 'Eggs', 2, 'large', '', 7),
('550e8400-e29b-41d4-a716-446655440004', 'Vanilla extract', 2, 'tsp', '', 8),
('550e8400-e29b-41d4-a716-446655440004', 'Chocolate chips', 2, 'cups', 'semi-sweet', 9),

-- Thai Green Curry ingredients
('550e8400-e29b-41d4-a716-446655440005', 'Chicken breast', 1, 'lb', 'cut into pieces', 1),
('550e8400-e29b-41d4-a716-446655440005', 'Green curry paste', 3, 'tbsp', 'Thai', 2),
('550e8400-e29b-41d4-a716-446655440005', 'Coconut milk', 14, 'oz', '1 can, full-fat', 3),
('550e8400-e29b-41d4-a716-446655440005', 'Fish sauce', 2, 'tbsp', '', 4),
('550e8400-e29b-41d4-a716-446655440005', 'Palm sugar', 1, 'tbsp', 'or brown sugar', 5),
('550e8400-e29b-41d4-a716-446655440005', 'Bell pepper', 1, 'large', 'sliced', 6),
('550e8400-e29b-41d4-a716-446655440005', 'Thai eggplant', 1, 'cup', 'quartered', 7),
('550e8400-e29b-41d4-a716-446655440005', 'Thai basil', 0.5, 'cup', 'fresh leaves', 8),
('550e8400-e29b-41d4-a716-446655440005', 'Lime juice', 1, 'tbsp', 'fresh', 9),
('550e8400-e29b-41d4-a716-446655440005', 'Vegetable oil', 2, 'tbsp', '', 10),
('550e8400-e29b-41d4-a716-446655440005', 'Jasmine rice', 2, 'cups', 'cooked, for serving', 11);

-- Insert nutrition data for some recipes
INSERT INTO nutrition (recipe_id, calories, protein_g, carbs_g, fat_g, fiber_g, sugar_g, sodium_mg) VALUES
('550e8400-e29b-41d4-a716-446655440001', 485, 18.5, 62.0, 18.2, 4.5, 8.3, 680),
('550e8400-e29b-41d4-a716-446655440002', 420, 35.0, 28.0, 22.0, 6.0, 4.0, 850),
('550e8400-e29b-41d4-a716-446655440004', 180, 2.5, 24.0, 9.0, 1.0, 14.0, 140),
('550e8400-e29b-41d4-a716-446655440005', 380, 28.0, 15.0, 25.0, 3.0, 8.0, 920);
