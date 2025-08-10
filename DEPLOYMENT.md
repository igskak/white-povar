# Production Deployment Guide

This guide walks you through deploying the White-Label Cooking App to production using Supabase, Render, and Firebase.

## Prerequisites

- GitHub account with this repository
- Supabase account
- Render account
- Firebase account
- Domain name (optional)

## 1. Supabase Setup

### Create Project
1. Go to [supabase.com](https://supabase.com) and create a new project
2. Choose a project name and database password
3. Wait for the project to be created

### Database Schema
1. Go to the SQL Editor in your Supabase dashboard
2. Run the following SQL to create the database schema:

```sql
-- Create tables
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

-- Enable Row Level Security
ALTER TABLE chefs ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_configurations ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Anyone can view recipes" ON recipes FOR SELECT USING (true);
CREATE POLICY "Chefs can manage their own recipes" ON recipes FOR ALL USING (auth.uid() = chef_id);
CREATE POLICY "Anyone can view ingredients" ON ingredients FOR SELECT USING (true);
CREATE POLICY "Chefs can manage ingredients for their recipes" ON ingredients FOR ALL USING (
  EXISTS (SELECT 1 FROM recipes WHERE recipes.id = ingredients.recipe_id AND recipes.chef_id = auth.uid())
);
```

### Storage Setup
1. Go to Storage in your Supabase dashboard
2. Create a new bucket called `recipe-images`
3. Set it to public
4. Add storage policies:

```sql
-- Storage policies
CREATE POLICY "Anyone can view recipe images" ON storage.objects
  FOR SELECT USING (bucket_id = 'recipe-images');

CREATE POLICY "Authenticated users can upload recipe images" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'recipe-images' AND auth.role() = 'authenticated');
```

### Get Credentials
1. Go to Settings > API in your Supabase dashboard
2. Copy the following values:
   - Project URL
   - Anon (public) key
   - Service role key
   - Database URL (from Database settings)

## 2. Backend Deployment (Render)

### Connect GitHub
1. Go to [render.com](https://render.com) and sign up
2. Connect your GitHub account
3. Create a new Web Service
4. Select this repository
5. Choose the `backend` directory as the root

### Configure Service
- **Build Command**: `pip install -r requirements.txt`
- **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
- **Environment**: Python 3.11

### Environment Variables
Add the following environment variables in Render:

```
ENVIRONMENT=production
SECRET_KEY=<generate-a-secure-random-key>
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
SUPABASE_URL=<your-supabase-project-url>
SUPABASE_KEY=<your-supabase-anon-key>
SUPABASE_SERVICE_KEY=<your-supabase-service-role-key>
DATABASE_URL=<your-supabase-database-url>
OPENAI_API_KEY=<your-openai-api-key>
FIREBASE_PROJECT_ID=<your-firebase-project-id>
```

### Deploy
1. Click "Create Web Service"
2. Render will automatically deploy when you push to the main branch
3. Note your backend URL (e.g., `https://your-app.onrender.com`)

## 3. Frontend Deployment (Firebase)

### Firebase Setup
1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project
3. Enable Hosting in the Firebase console

### Local Setup
```bash
cd frontend
npm install -g firebase-tools
firebase login
firebase init hosting
```

### GitHub Actions Setup
1. Generate a Firebase service account key:
   ```bash
   firebase service-accounts:generate-key service-account.json
   ```

2. Add the following secrets to your GitHub repository:
   - `FIREBASE_SERVICE_ACCOUNT`: Content of the service account JSON
   - `FIREBASE_PROJECT_ID`: Your Firebase project ID
   - `API_BASE_URL`: Your Render backend URL
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_ANON_KEY`: Your Supabase anon key

### Deploy
1. Push to the main branch
2. GitHub Actions will automatically build and deploy
3. Your app will be available at `https://your-project.web.app`

## 4. Mobile App Deployment

### Android (Google Play Store)
```bash
cd frontend
flutter build appbundle --release --dart-define=API_BASE_URL=https://your-app.onrender.com --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### iOS (Apple App Store)
```bash
cd frontend
flutter build ios --release --dart-define=API_BASE_URL=https://your-app.onrender.com --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## 5. Domain Setup (Optional)

### Custom Domain for Backend
1. In Render dashboard, go to your service settings
2. Add your custom domain
3. Configure DNS records as instructed

### Custom Domain for Frontend
1. In Firebase console, go to Hosting
2. Add custom domain
3. Configure DNS records as instructed

## 6. Monitoring and Maintenance

### Backend Monitoring
- Use Render's built-in metrics
- Monitor logs in Render dashboard
- Set up alerts for downtime

### Frontend Monitoring
- Use Firebase Analytics
- Monitor performance in Firebase console
- Set up crash reporting

### Database Monitoring
- Monitor usage in Supabase dashboard
- Set up alerts for high usage
- Regular backups (automatic in Supabase)

## Troubleshooting

### Common Issues
1. **CORS errors**: Update `allowed_origins` in backend settings
2. **Database connection**: Check DATABASE_URL format
3. **Build failures**: Check environment variables
4. **Authentication issues**: Verify Supabase keys

### Support
- Backend logs: Available in Render dashboard
- Frontend logs: Available in browser dev tools
- Database logs: Available in Supabase dashboard

## Security Checklist

- [ ] All environment variables are set correctly
- [ ] Database RLS policies are enabled
- [ ] CORS is configured for production domains only
- [ ] HTTPS is enabled everywhere
- [ ] API keys are kept secret
- [ ] Regular security updates
