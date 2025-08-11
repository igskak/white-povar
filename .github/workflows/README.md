# GitHub Actions Workflows

This directory contains the CI/CD workflows for the White Povar project.

## Workflows

### 1. `ci.yml` - Continuous Integration
- **Triggers**: Push/PR to main/develop branches
- **Purpose**: Run tests, linting, and build validation
- **Components**:
  - Frontend: Flutter analysis, tests, build verification
  - Backend: Python linting, tests, import validation

### 2. `deploy-frontend.yml` - Frontend Deployment
- **Triggers**: Push to main (frontend changes), manual dispatch
- **Purpose**: Deploy Flutter web app to Firebase Hosting
- **Features**:
  - Production deployment on main branch
  - Preview deployments for PRs
  - Environment variable injection via GitHub Secrets

### 3. `deploy-backend.yml` - Backend Deployment  
- **Triggers**: Push to main (backend changes), manual dispatch
- **Purpose**: Deploy FastAPI backend to Render
- **Features**:
  - Automated deployment via webhook
  - Environment validation

## Required GitHub Secrets

### Frontend Deployment
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Supabase anonymous key
- `API_BASE_URL`: Backend API base URL (optional, defaults to your backend)
- `FIREBASE_TOKEN`: Firebase deployment token

### Backend Deployment
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Supabase anonymous key  
- `SUPABASE_SERVICE_KEY`: Supabase service role key
- `OPENAI_API_KEY`: OpenAI API key for AI features
- `SECRET_KEY`: JWT secret key for authentication
- `RENDER_DEPLOY_HOOK`: Render.com deploy webhook URL

## Setup Instructions

### 1. Configure Firebase Token
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login and get token
firebase login:ci
# Copy the token and add it to GitHub Secrets as FIREBASE_TOKEN
```

### 2. Configure Render Deploy Hook
1. Go to your Render.com service dashboard
2. Navigate to Settings → Deploy Hook
3. Copy the webhook URL
4. Add it to GitHub Secrets as `RENDER_DEPLOY_HOOK`

### 3. Add Environment Secrets
1. Go to GitHub repository → Settings → Secrets and variables → Actions
2. Add all required secrets listed above
3. Ensure values match your `.env` files

## Manual Deployment

You can trigger deployments manually:
1. Go to Actions tab in GitHub
2. Select the workflow you want to run
3. Click "Run workflow"
4. Choose the branch and click "Run workflow"

## Troubleshooting

### Common Issues

1. **Flutter build fails**: Check that all required dart-define values are provided
2. **Firebase deployment fails**: Verify FIREBASE_TOKEN is valid and has permissions
3. **Backend tests fail**: Ensure all environment variables are properly set
4. **Render deployment fails**: Check that RENDER_DEPLOY_HOOK URL is correct

### Debug Steps
1. Check workflow logs in the Actions tab
2. Verify all secrets are configured
3. Test builds locally with same environment variables
4. Check service status (Firebase, Render, Supabase)
# Force GitHub Actions refresh - Mon Aug 11 23:40:02 CEST 2025
