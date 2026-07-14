# GitHub Actions Workflows

This directory contains the CI/CD workflows for the White Povar project.

## Workflows

### 1. `ci.yml` - Continuous Integration
- **Triggers**: Push/PR to main/develop branches
- **Purpose**: Run tests, linting, and build validation
- **Components**:
  - Frontend: Flutter analysis, tests, build verification
  - Backend: Python linting, tests, import validation

Production deployment is handled by Render Blueprint (`render.yaml`) after GitHub checks pass.

## Required GitHub Secrets

### Backend CI
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Supabase anonymous key  
- `SUPABASE_SERVICE_KEY`: Supabase service role key
- `OPENAI_API_KEY`: OpenAI API key for AI features
- `SECRET_KEY`: JWT secret key for authentication

## Setup Instructions

### 1. Add Environment Secrets
1. Go to GitHub repository → Settings → Secrets and variables → Actions
2. Add all required secrets listed above
3. Ensure values match your `.env` files

### 2. Deploy with Render Blueprint
1. Open Render Dashboard and create/apply the Blueprint from `render.yaml`
2. Use workspace `My workspace`
3. Fill the Render environment variables marked `sync: false`
4. Let Render auto-deploy after GitHub checks pass

## Manual Deployment

You can trigger CI manually from the GitHub Actions tab. Production deploys are triggered by Render after checks pass.

## Troubleshooting

### Common Issues

1. **Flutter build fails**: Check that all required dart-define values are provided
2. **Backend tests fail**: Ensure all environment variables are properly set
3. **Render deployment fails**: Check Blueprint service logs and required Render env vars

### Debug Steps
1. Check workflow logs in the Actions tab
2. Verify all secrets are configured
3. Test builds locally with same environment variables
4. Check service status (Render, Supabase)
