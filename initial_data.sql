-- Initial data for White Povar database

-- =====================================================
-- UNITS OF MEASUREMENT
-- =====================================================

-- Base units (metric system)
INSERT INTO units (id, name_en, name_it, abbreviation_en, abbreviation_it, unit_type, system, is_base_unit, conversion_factor) VALUES
-- Mass units
('00000000-0000-0000-0000-000000000001', 'gram', 'grammo', 'g', 'g', 'mass', 'metric', true, 1.0),
('00000000-0000-0000-0000-000000000002', 'kilogram', 'chilogrammo', 'kg', 'kg', 'mass', 'metric', false, 1000.0),

-- Volume units (metric)
('00000000-0000-0000-0000-000000000010', 'milliliter', 'millilitro', 'ml', 'ml', 'volume', 'metric', true, 1.0),
('00000000-0000-0000-0000-000000000011', 'liter', 'litro', 'l', 'l', 'volume', 'metric', false, 1000.0),
('00000000-0000-0000-0000-000000000012', 'deciliter', 'decilitro', 'dl', 'dl', 'volume', 'metric', false, 100.0),

-- Count units
('00000000-0000-0000-0000-000000000020', 'piece', 'pezzo', 'pc', 'pz', 'count', 'metric', true, 1.0),
('00000000-0000-0000-0000-000000000021', 'dozen', 'dozzina', 'dz', 'dz', 'count', 'metric', false, 12.0),

-- Common cooking units (US/Imperial)
('00000000-0000-0000-0000-000000000030', 'cup', 'tazza', 'cup', 'tazza', 'volume', 'us', false, 236.588),
('00000000-0000-0000-0000-000000000031', 'tablespoon', 'cucchiaio', 'tbsp', 'cucchiaio', 'volume', 'us', false, 14.787),
('00000000-0000-0000-0000-000000000032', 'teaspoon', 'cucchiaino', 'tsp', 'cucchiaino', 'volume', 'us', false, 4.929),
('00000000-0000-0000-0000-000000000033', 'fluid ounce', 'oncia fluida', 'fl oz', 'fl oz', 'volume', 'us', false, 29.574),

-- Italian specific units
('00000000-0000-0000-0000-000000000040', 'bicchiere', 'bicchiere', 'bicchiere', 'bicchiere', 'volume', 'metric', false, 200.0),
('00000000-0000-0000-0000-000000000041', 'pizzico', 'pizzico', 'pizzico', 'pizzico', 'count', 'metric', false, 1.0),
('00000000-0000-0000-0000-000000000042', 'quanto basta', 'quanto basta', 'q.b.', 'q.b.', 'count', 'metric', false, 1.0);

-- Set base unit references
UPDATE units SET base_unit_id = '00000000-0000-0000-0000-000000000001' WHERE unit_type = 'mass' AND NOT is_base_unit;
UPDATE units SET base_unit_id = '00000000-0000-0000-0000-000000000010' WHERE unit_type = 'volume' AND NOT is_base_unit;
UPDATE units SET base_unit_id = '00000000-0000-0000-0000-000000000020' WHERE unit_type = 'count' AND NOT is_base_unit;

-- =====================================================
-- INGREDIENT CATEGORIES
-- =====================================================

INSERT INTO ingredient_categories (id, name_en, name_it, description_en, description_it, color_hex, sort_order) VALUES
('10000000-0000-0000-0000-000000000001', 'Vegetables', 'Verdure', 'Fresh and preserved vegetables', 'Verdure fresche e conservate', '#22C55E', 1),
('10000000-0000-0000-0000-000000000002', 'Proteins', 'Proteine', 'Meat, fish, poultry, and plant proteins', 'Carne, pesce, pollame e proteine vegetali', '#EF4444', 2),
('10000000-0000-0000-0000-000000000003', 'Dairy & Eggs', 'Latticini e Uova', 'Milk products and eggs', 'Prodotti lattiero-caseari e uova', '#F59E0B', 3),
('10000000-0000-0000-0000-000000000004', 'Grains & Cereals', 'Cereali e Pasta', 'Rice, pasta, bread, and cereals', 'Riso, pasta, pane e cereali', '#D97706', 4),
('10000000-0000-0000-0000-000000000005', 'Herbs & Spices', 'Erbe e Spezie', 'Fresh and dried herbs and spices', 'Erbe e spezie fresche e secche', '#10B981', 5),
('10000000-0000-0000-0000-000000000006', 'Oils & Fats', 'Oli e Grassi', 'Cooking oils, butter, and other fats', 'Oli da cucina, burro e altri grassi', '#F59E0B', 6),
('10000000-0000-0000-0000-000000000007', 'Fruits', 'Frutta', 'Fresh and preserved fruits', 'Frutta fresca e conservata', '#EC4899', 7),
('10000000-0000-0000-0000-000000000008', 'Nuts & Seeds', 'Noci e Semi', 'Nuts, seeds, and nut products', 'Noci, semi e prodotti a base di noci', '#8B5CF6', 8),
('10000000-0000-0000-0000-000000000009', 'Condiments & Sauces', 'Condimenti e Salse', 'Sauces, vinegars, and condiments', 'Salse, aceti e condimenti', '#6366F1', 9),
('10000000-0000-0000-0000-000000000010', 'Beverages', 'Bevande', 'Wines, stocks, and cooking liquids', 'Vini, brodi e liquidi da cucina', '#3B82F6', 10),
('10000000-0000-0000-0000-000000000099', 'Other', 'Altro', 'Miscellaneous ingredients', 'Ingredienti vari', '#6B7280', 99);

-- =====================================================
-- RECIPE CATEGORIES
-- =====================================================

INSERT INTO recipe_categories (id, name_en, name_it, description_en, description_it, color_hex, sort_order) VALUES
('20000000-0000-0000-0000-000000000001', 'Appetizers', 'Antipasti', 'Starters and small plates', 'Antipasti e piccoli piatti', '#F59E0B', 1),
('20000000-0000-0000-0000-000000000002', 'First Courses', 'Primi Piatti', 'Pasta, risotto, and soups', 'Pasta, risotto e zuppe', '#EF4444', 2),
('20000000-0000-0000-0000-000000000003', 'Second Courses', 'Secondi Piatti', 'Main dishes with meat or fish', 'Piatti principali con carne o pesce', '#10B981', 3),
('20000000-0000-0000-0000-000000000004', 'Side Dishes', 'Contorni', 'Vegetable sides and accompaniments', 'Contorni di verdure e accompagnamenti', '#22C55E', 4),
('20000000-0000-0000-0000-000000000005', 'Desserts', 'Dolci', 'Sweet treats and desserts', 'Dolci e dessert', '#EC4899', 5),
('20000000-0000-0000-0000-000000000006', 'Beverages', 'Bevande', 'Drinks and cocktails', 'Bevande e cocktail', '#3B82F6', 6),
('20000000-0000-0000-0000-000000000007', 'Bread & Baked Goods', 'Pane e Prodotti da Forno', 'Breads, pizza, and baked items', 'Pane, pizza e prodotti da forno', '#D97706', 7),
('20000000-0000-0000-0000-000000000008', 'Salads', 'Insalate', 'Fresh and composed salads', 'Insalate fresche e composte', '#22C55E', 8),
('20000000-0000-0000-0000-000000000099', 'Other', 'Altro', 'Miscellaneous recipes', 'Ricette varie', '#6B7280', 99);

-- =====================================================
-- CHEFS
-- =====================================================

-- Max Mariola (our main chef)
INSERT INTO chefs (id, name, bio, avatar_url, website_url, social_links, is_verified, is_active) VALUES
('a06dccc2-0e3d-45ee-9d16-cb348898dd7a', 
 'Max Mariola', 
 'Renowned Italian chef and cookbook author, known for his modern take on traditional Italian cuisine. Max combines classic techniques with contemporary presentation to create memorable dining experiences.',
 'https://example.com/max-mariola-avatar.jpg',
 'https://maxmariola.com',
 '{"instagram": "@maxmariola", "youtube": "MaxMariolaChef", "facebook": "MaxMariolaOfficial"}',
 true,
 true);

-- =====================================================
-- COMMON BASE INGREDIENTS
-- =====================================================

-- Essential Italian cooking ingredients
INSERT INTO base_ingredients (id, name_en, name_it, category_id, default_unit_id, aliases, density_g_per_ml) VALUES
-- Vegetables
('30000000-0000-0000-0000-000000000001', 'Onion', 'Cipolla', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '{"onions", "yellow onion"}', NULL),
('30000000-0000-0000-0000-000000000002', 'Garlic', 'Aglio', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000020', '{"garlic cloves", "aglio"}', NULL),
('30000000-0000-0000-0000-000000000003', 'Tomato', 'Pomodoro', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '{"tomatoes", "pomodori"}', NULL),
('30000000-0000-0000-0000-000000000004', 'Carrot', 'Carota', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '{"carrots", "carote"}', NULL),
('30000000-0000-0000-0000-000000000005', 'Celery', 'Sedano', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '{"celery stalks"}', NULL),

-- Herbs & Spices
('30000000-0000-0000-0000-000000000010', 'Basil', 'Basilico', '10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', '{"fresh basil", "basilico fresco"}', NULL),
('30000000-0000-0000-0000-000000000011', 'Parsley', 'Prezzemolo', '10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', '{"fresh parsley", "prezzemolo fresco"}', NULL),
('30000000-0000-0000-0000-000000000012', 'Rosemary', 'Rosmarino', '10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', '{"fresh rosemary"}', NULL),
('30000000-0000-0000-0000-000000000013', 'Salt', 'Sale', '10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', '{"sea salt", "table salt"}', NULL),
('30000000-0000-0000-0000-000000000014', 'Black Pepper', 'Pepe Nero', '10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', '{"pepper", "ground black pepper"}', NULL),

-- Oils & Fats
('30000000-0000-0000-0000-000000000020', 'Extra Virgin Olive Oil', 'Olio Extravergine di Oliva', '10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000010', '{"olive oil", "EVOO"}', 0.915),
('30000000-0000-0000-0000-000000000021', 'Butter', 'Burro', '10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000001', '{"unsalted butter"}', NULL),

-- Dairy & Eggs
('30000000-0000-0000-0000-000000000030', 'Parmigiano Reggiano', 'Parmigiano Reggiano', '10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', '{"parmesan", "parmigiano"}', NULL),
('30000000-0000-0000-0000-000000000031', 'Mozzarella', 'Mozzarella', '10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', '{"fresh mozzarella"}', NULL),
('30000000-0000-0000-0000-000000000032', 'Eggs', 'Uova', '10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000020', '{"egg", "uovo"}', NULL),

-- Grains & Pasta
('30000000-0000-0000-0000-000000000040', 'Pasta', 'Pasta', '10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', '{"spaghetti", "penne", "fusilli"}', NULL),
('30000000-0000-0000-0000-000000000041', 'Rice', 'Riso', '10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', '{"arborio rice", "carnaroli"}', NULL),
('30000000-0000-0000-0000-000000000042', 'Bread', 'Pane', '10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', '{"stale bread", "pane raffermo"}', NULL);

-- =====================================================
-- INDEXES AND FINAL SETUP
-- =====================================================

-- Refresh materialized views if any
-- REFRESH MATERIALIZED VIEW IF EXISTS recipe_search_view;

-- Update statistics
ANALYZE;
