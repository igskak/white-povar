# Database Schema Analysis & Recommendations

## Current Schema Issues

### 1. Ingredients Table Structure
**Current Problem**: The `ingredients` table stores `amount` and `unit` directly tied to recipes, preventing ingredient reuse and causing data duplication.

```sql
-- Current (problematic)
CREATE TABLE ingredients (
    id UUID PRIMARY KEY,
    recipe_id UUID NOT NULL REFERENCES recipes(id),
    name VARCHAR(200) NOT NULL,  -- Duplicated across recipes
    amount DECIMAL(10,2) NOT NULL,
    unit VARCHAR(50) NOT NULL,   -- Free text, no validation
    notes TEXT,
    "order" INTEGER NOT NULL
);
```

**Issues**:
- Same ingredient (e.g., "Salt") stored multiple times with different names
- No standardization of ingredient names
- Units are free text without validation or conversion
- No nutritional data per ingredient
- No ingredient categorization

### 2. Unit System Problems
**Current**: Units stored as `VARCHAR(50)` without validation
**Issues**:
- Inconsistent unit names ("tsp", "teaspoon", "t.")
- No conversion between metric/imperial
- No canonical storage format
- No validation of unit-ingredient compatibility

### 3. Multi-language Support
**Current**: Single language fields only
**Issues**:
- No support for multiple languages
- No canonical English version for search/indexing
- No translation tracking

### 4. Data Normalization
**Current**: Limited normalization
**Issues**:
- Ingredient data duplication
- No reusable ingredient definitions
- No standardized measurements

## Recommended Schema Changes

### 1. Normalized Ingredients Structure

```sql
-- Base ingredients (reusable definitions)
CREATE TABLE base_ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en VARCHAR(200) NOT NULL,           -- Canonical English name
    name_original VARCHAR(200),              -- Original language name
    original_language VARCHAR(5),            -- ISO language code
    category_id UUID REFERENCES ingredient_categories(id),
    density_g_per_ml DECIMAL(8,4),          -- For volume/weight conversion
    default_unit_id UUID REFERENCES units(id),
    nutritional_data JSONB,                 -- Per 100g nutritional info
    aliases TEXT[],                         -- Alternative names
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ingredient categories
CREATE TABLE ingredient_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en VARCHAR(100) NOT NULL,
    name_original VARCHAR(100),
    original_language VARCHAR(5),
    parent_id UUID REFERENCES ingredient_categories(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Recipe-ingredient junction table
CREATE TABLE recipe_ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    base_ingredient_id UUID NOT NULL REFERENCES base_ingredients(id),
    amount_canonical DECIMAL(12,4) NOT NULL,    -- Always in metric base units
    unit_canonical_id UUID NOT NULL REFERENCES units(id),
    amount_display DECIMAL(12,4),              -- Original/display amount
    unit_display_id UUID REFERENCES units(id), -- Original/display unit
    notes TEXT,
    "order" INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 2. Units Standardization

```sql
-- Units reference table
CREATE TABLE units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_en VARCHAR(50) NOT NULL,
    name_original VARCHAR(50),
    original_language VARCHAR(5),
    abbreviation_en VARCHAR(10) NOT NULL,
    unit_type VARCHAR(20) NOT NULL,          -- 'mass', 'volume', 'count', 'length'
    system VARCHAR(10) NOT NULL,             -- 'metric', 'imperial', 'us'
    base_unit_id UUID REFERENCES units(id),  -- Reference to metric base unit
    conversion_factor DECIMAL(20,10),        -- Factor to convert to base unit
    is_base_unit BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Unit conversion examples
INSERT INTO units (name_en, abbreviation_en, unit_type, system, is_base_unit) VALUES
('gram', 'g', 'mass', 'metric', TRUE),
('kilogram', 'kg', 'mass', 'metric', FALSE),
('milliliter', 'ml', 'volume', 'metric', TRUE),
('liter', 'l', 'volume', 'metric', FALSE),
('teaspoon', 'tsp', 'volume', 'us', FALSE),
('tablespoon', 'tbsp', 'volume', 'us', FALSE),
('cup', 'cup', 'volume', 'us', FALSE),
('ounce', 'oz', 'mass', 'imperial', FALSE),
('pound', 'lb', 'mass', 'imperial', FALSE);
```

### 3. Multi-language Recipe Support

```sql
-- Enhanced recipes table
ALTER TABLE recipes 
ADD COLUMN title_original VARCHAR(200),
ADD COLUMN title_en VARCHAR(200),
ADD COLUMN description_original TEXT,
ADD COLUMN description_en TEXT,
ADD COLUMN original_language VARCHAR(5) DEFAULT 'en',
ADD COLUMN instructions_original TEXT[],
ADD COLUMN instructions_en TEXT[];

-- Update existing recipes to use English as canonical
UPDATE recipes SET 
    title_en = title,
    description_en = description,
    instructions_en = instructions,
    original_language = 'en';
```

### 4. Enhanced Data Types & Constraints

```sql
-- Add proper constraints and indexes
ALTER TABLE recipe_ingredients 
ADD CONSTRAINT check_positive_amount CHECK (amount_canonical > 0),
ADD CONSTRAINT check_positive_display_amount CHECK (amount_display IS NULL OR amount_display > 0);

-- Indexes for performance
CREATE INDEX idx_base_ingredients_name_en ON base_ingredients(name_en);
CREATE INDEX idx_base_ingredients_category ON base_ingredients(category_id);
CREATE INDEX idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_id);
CREATE INDEX idx_recipe_ingredients_ingredient ON recipe_ingredients(base_ingredient_id);
CREATE INDEX idx_units_type_system ON units(unit_type, system);

-- Full-text search on English content
CREATE INDEX idx_recipes_search_en ON recipes USING gin(
    to_tsvector('english', COALESCE(title_en, '') || ' ' || COALESCE(description_en, ''))
);
CREATE INDEX idx_base_ingredients_search ON base_ingredients USING gin(
    to_tsvector('english', name_en || ' ' || array_to_string(aliases, ' '))
);
```

## Migration Strategy

### Phase 1: Add New Tables
1. Create `units`, `ingredient_categories`, `base_ingredients` tables
2. Populate with standard data
3. Add new columns to existing tables

### Phase 2: Data Migration
1. Extract unique ingredients from current `ingredients` table
2. Create `base_ingredients` entries with English normalization
3. Populate `recipe_ingredients` with canonical amounts
4. Preserve original data for rollback

### Phase 3: API Updates
1. Update Pydantic models
2. Implement normalization service
3. Add unit conversion utilities
4. Update endpoints to support localization

## Benefits

1. **Data Consistency**: Standardized ingredient names and units
2. **Reusability**: Ingredients defined once, used many times
3. **Localization**: Multi-language support with English canonical
4. **Conversion**: Automatic unit conversion between systems
5. **Search**: Better search with normalized English content
6. **Nutrition**: Accurate nutritional calculations
7. **Scalability**: Easier to add new languages and units

## Implementation Priority

1. **High Priority**: Units table and conversion system
2. **High Priority**: Base ingredients normalization
3. **Medium Priority**: Multi-language support
4. **Medium Priority**: Nutritional data integration
5. **Low Priority**: Advanced categorization features
