# White-Label Cooking App

A comprehensive white-label cooking application built with FastAPI backend and Flutter frontend, designed for chefs to create their own branded cooking apps.

## Project Structure

```
White Povar/
├── backend/           # FastAPI backend
│   ├── app/
│   │   ├── api/       # API routes
│   │   ├── core/      # Core configuration
│   │   ├── models/    # Database models
│   │   └── services/  # Business logic
│   ├── requirements.txt
│   └── main.py
├── frontend/          # Flutter frontend
│   ├── lib/
│   │   ├── core/      # App configuration
│   │   ├── features/  # Feature modules
│   │   └── main.dart
│   └── pubspec.yaml
└── README.md
```

## Features

### Backend (FastAPI)
- **Chef Management**: Registration, authentication, and profile management
- **Recipe Management**: CRUD operations for recipes with ingredients and instructions
- **White-Label Configuration**: Customizable branding and themes per chef
- **Image Upload**: Support for recipe and chef profile images
- **RESTful API**: Well-documented API endpoints with automatic OpenAPI documentation

### Frontend (Flutter)
- **Cross-Platform**: Runs on iOS, Android, and Web
- **Authentication**: Firebase Auth ready; Supabase client configured in app
- **Recipe Browsing**: Beautiful recipe cards with filtering and search
- **Responsive Design**: Adaptive UI that works on all screen sizes
- **State Management**: Riverpod for efficient state management
- **Theming**: Dynamic theming based on chef configuration

## Technology Stack

### Backend
- **FastAPI**: Modern, fast web framework for building APIs
- **SQLAlchemy**: SQL toolkit and ORM
- **Pydantic**: Data validation using Python type annotations
- **Uvicorn**: ASGI server implementation
- **Python 3.11+**: Latest Python features

### Frontend
- **Flutter**: Google's UI toolkit for cross-platform development
- **Riverpod**: State management solution
- **Go Router**: Declarative routing
- **Dio**: HTTP client for API communication
- **Hive**: Local storage solution
- **Supabase Flutter**: Database, auth, storage
- **Firebase Core/Auth**: Platform auth integration and hosting

## Getting Started

### Prerequisites
- Python 3.11+
- Flutter SDK 3.5+
- Node.js (for web development)

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Run the development server:
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

5. Access the API documentation at: http://localhost:8000/docs

### Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies (includes Supabase and Firebase):
   ```bash
   flutter pub get
   ```

3. Run the app (pass runtime config with dart-define):
   ```bash
   # For web
   flutter run -d chrome --web-port 3000 \
     --dart-define=API_BASE_URL=http://localhost:8000 \
     --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<your-anon-key>

   # For mobile (with device/emulator connected)
   flutter run \
     --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
     --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
   ```

4. Access the app at: http://localhost:3000

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register a new chef
- `POST /api/auth/login` - Login chef
- `GET /api/auth/me` - Get current chef profile

### Recipes
- `GET /api/recipes` - List all recipes
- `POST /api/recipes` - Create a new recipe
- `GET /api/recipes/{id}` - Get recipe by ID
- `PUT /api/recipes/{id}` - Update recipe
- `DELETE /api/recipes/{id}` - Delete recipe

### Configuration
- `GET /api/config/{chef_id}` - Get chef's app configuration
- `PUT /api/config/{chef_id}` - Update chef's app configuration

## Development

### Backend Development
- The backend uses FastAPI with automatic API documentation
- Database models are defined using SQLAlchemy
- API routes are organized by feature in the `app/api` directory
- Business logic is separated into services

### Frontend Development
- The frontend follows a feature-based architecture
- Each feature has its own models, providers, and UI components
- State management is handled with Riverpod
- Navigation uses Go Router for type-safe routing

## Production Deployment

### Database Setup (Supabase)
1. **Create Supabase Project**:
   - Go to [supabase.com](https://supabase.com) and create a new project
   - Note down the project URL and anon key

2. **Database Schema**:
   ```sql
   -- Run in Supabase SQL Editor
   CREATE TABLE chefs (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     email VARCHAR UNIQUE NOT NULL,
     hashed_password VARCHAR NOT NULL,
     name VARCHAR NOT NULL,
     bio TEXT,
     profile_image_url VARCHAR,
     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
     updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   );

   CREATE TABLE recipes (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     chef_id UUID REFERENCES chefs(id) ON DELETE CASCADE,
     title VARCHAR NOT NULL,
     description TEXT,
     cuisine VARCHAR,
     category VARCHAR,
     difficulty INTEGER CHECK (difficulty >= 1 AND difficulty <= 5),
     prep_time_minutes INTEGER,
     cook_time_minutes INTEGER,
     total_time_minutes INTEGER,
     servings INTEGER,
     instructions TEXT[],
     images VARCHAR[],
     tags VARCHAR[],
     is_featured BOOLEAN DEFAULT FALSE,
     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
     updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   );

   CREATE TABLE ingredients (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
     name VARCHAR NOT NULL,
     amount DECIMAL,
     unit VARCHAR,
     notes TEXT,
     order_index INTEGER,
     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   );

   CREATE TABLE app_configurations (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     chef_id UUID REFERENCES chefs(id) ON DELETE CASCADE UNIQUE,
     app_name VARCHAR NOT NULL,
     primary_color VARCHAR DEFAULT '#E74C3C',
     secondary_color VARCHAR DEFAULT '#F39C12',
     accent_color VARCHAR DEFAULT '#27AE60',
     background_color VARCHAR DEFAULT '#FFFFFF',
     text_color VARCHAR DEFAULT '#2C3E50',
     font_family VARCHAR DEFAULT 'Inter',
     logo_url VARCHAR,
     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
     updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   );
   ```

3. **Row Level Security (RLS)**:
   ```sql
   -- Enable RLS
   ALTER TABLE chefs ENABLE ROW LEVEL SECURITY;
   ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
   ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
   ALTER TABLE app_configurations ENABLE ROW LEVEL SECURITY;

   -- Policies for chefs
   CREATE POLICY "Chefs can view their own data" ON chefs
     FOR SELECT USING (auth.uid() = id);

   CREATE POLICY "Chefs can update their own data" ON chefs
     FOR UPDATE USING (auth.uid() = id);

   -- Policies for recipes
   CREATE POLICY "Anyone can view recipes" ON recipes
     FOR SELECT USING (true);

   CREATE POLICY "Chefs can manage their own recipes" ON recipes
     FOR ALL USING (auth.uid() = chef_id);
   ```

### Backend Deployment (Render)
1. **Update Backend for Supabase**:
   ```python
   # requirements.txt - add Supabase client
   supabase==1.2.0
   asyncpg==0.29.0  # For async PostgreSQL
   ```

2. **Database Configuration**:
   ```python
   # app/core/config.py
   import os
   from supabase import create_client, Client

   SUPABASE_URL = os.getenv("SUPABASE_URL")
   SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY")
   DATABASE_URL = os.getenv("DATABASE_URL")  # Supabase PostgreSQL URL

   supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
   ```

3. **Render Deployment** (Auto-deploy via GitHub):
   - Connect your GitHub repository to Render
   - Create a new Web Service
   - Configure environment variables:
     ```
     SUPABASE_URL=https://your-project.supabase.co
     SUPABASE_ANON_KEY=your-anon-key
     DATABASE_URL=postgresql://postgres:[password]@db.your-project.supabase.co:5432/postgres
     SECRET_KEY=your-jwt-secret-key
     ALGORITHM=HS256
     ACCESS_TOKEN_EXPIRE_MINUTES=30
     ```
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`

### Frontend Deployment (Firebase Hosting)
1. **Firebase Setup**:
   ```bash
   cd frontend
   npm install -g firebase-tools
   firebase login
   firebase init hosting
   ```

2. **Build and Deploy** (provide runtime config):
   ```bash
   flutter build web --release \
     --dart-define=API_BASE_URL=https://your-backend.example.com \
     --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
   firebase deploy
   ```

3. **Environment Configuration**:
   ```dart
   // lib/core/config/app_config.dart
   class AppConfig {
     static const String supabaseUrl = String.fromEnvironment(
       'SUPABASE_URL',
       defaultValue: 'https://your-project.supabase.co',
     );

     static const String supabaseAnonKey = String.fromEnvironment(
       'SUPABASE_ANON_KEY',
       defaultValue: 'your-anon-key',
     );

     static const String apiBaseUrl = String.fromEnvironment(
       'API_BASE_URL',
       defaultValue: 'https://your-app.onrender.com',
     );
   }
   ```

### Mobile App Deployment
1. **Android (Google Play Store)**:
   ```bash
   # Build release
   flutter build appbundle --release

   # Upload to Google Play Console
   ```

2. **iOS (Apple App Store)**:
   ```bash
   # Build for iOS
   flutter build ios --release

   # Archive and upload via Xcode
   ```

### Automated Deployment Pipeline
Since GitHub is connected to Render, deployments are automatic:

1. **Backend Auto-Deploy**:
   - Push to `main` branch triggers Render deployment
   - Render automatically builds and deploys the FastAPI backend
   - Environment variables are preserved across deployments

2. **Frontend CI/CD** (GitHub Actions):
   ```yaml
   # .github/workflows/deploy-frontend.yml
   name: Deploy Frontend to Firebase
   on:
     push:
       branches: [main]
       paths: ['frontend/**']

   jobs:
     deploy:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - uses: subosito/flutter-action@v2
           with:
             flutter-version: '3.16.0'
         - name: Install dependencies
           run: |
             cd frontend
             flutter pub get
         - name: Build web
           run: |
             cd frontend
             flutter build web --release
         - name: Deploy to Firebase
           uses: FirebaseExtended/action-hosting-deploy@v0
           with:
             repoToken: '${{ secrets.GITHUB_TOKEN }}'
             firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
             projectId: your-firebase-project-id
             channelId: live
   ```

### File Storage (Supabase Storage)
1. **Setup Storage Bucket**:
   ```sql
   -- Create storage bucket in Supabase
   INSERT INTO storage.buckets (id, name, public)
   VALUES ('recipe-images', 'recipe-images', true);
   ```

2. **Storage Policies**:
   ```sql
   CREATE POLICY "Anyone can view recipe images" ON storage.objects
     FOR SELECT USING (bucket_id = 'recipe-images');

   CREATE POLICY "Authenticated users can upload recipe images" ON storage.objects
     FOR INSERT WITH CHECK (bucket_id = 'recipe-images' AND auth.role() = 'authenticated');
   ```

3. **Flutter Integration**:
   ```dart
   dependencies:
     supabase_flutter: ^1.10.25
   ```

### Monitoring & Security
1. **Supabase Dashboard**: Monitor database performance and usage
2. **Render Metrics**: Track backend performance and uptime
3. **Firebase Analytics**: Monitor frontend usage and crashes
4. **Environment Security**: All secrets stored as environment variables

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions, please open an issue in the GitHub repository.
# Test deployment Mon Aug 11 20:52:12 CEST 2025
