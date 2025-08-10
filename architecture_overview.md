# White-Label Cooking App - Architecture Overview

## System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │  FastAPI Backend │    │  External APIs  │
│                 │    │                 │    │                 │
│ • Recipe Views  │◄──►│ • REST API      │◄──►│ • OpenAI Vision │
│ • Photo Search  │    │ • Auth          │    │ • Firebase Auth │
│ • Local Storage │    │ • Business Logic│    │ • Supabase/PG   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## API Endpoint Specifications

### Authentication
- `POST /auth/register`
  - Body: `{email, password, chef_id?}`
  - Response: `{user_id, access_token, refresh_token}`
- `POST /auth/login`
  - Body: `{email, password}`
  - Response: `{user_id, access_token, refresh_token}`
- `POST /auth/refresh`
  - Body: `{refresh_token}`
  - Response: `{access_token}`

### Recipes
- `GET /recipes`
  - Query params: `cuisine, difficulty, max_time, category, chef_id, limit, offset`
  - Response: `{recipes: [Recipe], total_count, has_more}`
- `GET /recipes/{recipe_id}`
  - Response: `Recipe` object with full details
- `GET /recipes/featured`
  - Query params: `chef_id, limit`
  - Response: `{recipes: [Recipe]}`

### Search
- `POST /search/photo`
  - Body: `{image: base64_string, chef_id?}`
  - Response: `{ingredients: [string], suggested_recipes: [Recipe]}`
- `GET /search/text`
  - Query params: `q, chef_id, limit`
  - Response: `{recipes: [Recipe]}`

### White-label
- `GET /config/{chef_id}`
  - Response: `{theme, logo_url, chef_info, app_name}`

## Data Models

### User
```python
class User:
    id: UUID
    email: str
    password_hash: str
    chef_id: Optional[UUID]  # null for global users
    favorites: List[UUID]    # recipe IDs
    created_at: datetime
    updated_at: datetime
```

### Recipe
```python
class Recipe:
    id: UUID
    title: str
    description: str
    chef_id: UUID
    cuisine: str             # "Italian", "Mexican", etc.
    category: str            # "Breakfast", "Dinner", etc.
    difficulty: int          # 1-5 scale
    prep_time_minutes: int
    cook_time_minutes: int
    total_time_minutes: int  # computed
    servings: int
    ingredients: List[Ingredient]
    instructions: List[str]
    images: List[str]        # URLs
    nutrition: Optional[Nutrition]
    tags: List[str]
    is_featured: bool
    created_at: datetime
    updated_at: datetime
```

### Ingredient
```python
class Ingredient:
    id: UUID
    recipe_id: UUID
    name: str
    amount: float
    unit: str               # "cups", "tbsp", "pieces"
    notes: Optional[str]    # "chopped", "room temperature"
    order: int
```

### Chef (White-label config)
```python
class Chef:
    id: UUID
    name: str
    bio: str
    avatar_url: str
    app_name: str
    theme_config: dict      # colors, fonts
    logo_url: str
    social_links: dict
    created_at: datetime
```

## External Service Integration

### OpenAI Vision API
- **Purpose**: Analyze ingredient photos
- **Flow**: 
  1. User uploads photo → Base64 encode
  2. Send to OpenAI Vision with prompt: "List ingredients visible in this image"
  3. Parse response → Match against recipe database
  4. Return suggested recipes

### Firebase Auth (Frontend)
- **Purpose**: Social login (Google, Apple)
- **Flow**: Firebase token → Verify with backend → Issue JWT

### Supabase/PostgreSQL
- **Purpose**: Primary database
- **Tables**: users, recipes, ingredients, chefs, user_favorites
- **Features**: Row-level security for multi-tenant data

## State Management (Flutter)

### Riverpod Providers
```dart
// Recipe providers
final recipeListProvider = FutureProvider.family<List<Recipe>, RecipeFilters>
final recipeDetailProvider = FutureProvider.family<Recipe, String>
final featuredRecipesProvider = FutureProvider<List<Recipe>>

// Search providers  
final photoSearchProvider = StateNotifierProvider<PhotoSearchNotifier, PhotoSearchState>
final textSearchProvider = FutureProvider.family<List<Recipe>, String>

// Auth providers
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>
final userProvider = Provider<User?>

// White-label providers
final chefConfigProvider = FutureProvider.family<ChefConfig, String>
final themeProvider = Provider<ThemeData>
```

## Development Workflow

### Phase 1: Backend Foundation (Week 1-2)
1. **Setup FastAPI project structure**
   - Initialize with poetry/pip
   - Configure environment variables
   - Setup database connection
   
2. **Implement core models & database**
   - SQLAlchemy models
   - Alembic migrations
   - Seed data for testing

3. **Basic API endpoints**
   - Mock recipe endpoints with static data
   - Basic auth (JWT)
   - Health check endpoint

4. **OpenAI Vision integration**
   - Service class for API calls
   - Image processing utilities
   - Recipe matching logic

### Phase 2: Frontend Foundation (Week 3-4)
1. **Flutter project setup**
   - Clean architecture structure
   - Riverpod configuration
   - Navigation setup (go_router)

2. **Core UI components**
   - Recipe card widget
   - Search bar
   - Filter components
   - Loading states

3. **API integration**
   - HTTP client setup (dio)
   - Repository pattern
   - Error handling

4. **Recipe features**
   - Recipe list with filters
   - Recipe detail page
   - Local favorites (Hive/SharedPreferences)

### Phase 3: AI Search (Week 5)
1. **Photo picker integration**
   - Camera/gallery access
   - Image compression
   - Base64 encoding

2. **Search UI/UX**
   - Photo upload flow
   - Loading indicators
   - Results display

3. **Backend search optimization**
   - Ingredient matching algorithms
   - Recipe scoring/ranking
   - Performance optimization

### Phase 4: White-label System (Week 6)
1. **Theme system**
   - Dynamic theme loading
   - Chef configuration API
   - Asset management

2. **Multi-tenant data**
   - Chef-specific recipe filtering
   - Branding customization
   - Configuration management

### Phase 5: Deployment (Week 7-8)
1. **Backend deployment**
   - Docker containerization
   - Environment configuration
   - Database setup

2. **Mobile app builds**
   - Android/iOS configuration
   - App store preparation
   - Testing on devices

## Questions for Clarification

1. **Database Choice**: Prefer Supabase (managed) or self-hosted PostgreSQL?
2. **State Management**: Riverpod or Bloc preference for Flutter?
3. **Image Storage**: Where to store recipe images? (Supabase Storage, AWS S3, etc.)
4. **Authentication**: Use Firebase Auth tokens or implement custom JWT entirely?
5. **Recipe Data**: Will you provide initial recipe data, or should I create sample data?
6. **White-label Scope**: How many chef configurations do you plan to support initially?

Please review this architecture and confirm if it aligns with your vision. Once approved, I'll proceed with the step-by-step implementation starting with Phase 1.
