# White-Label Cooking App - Backend API

FastAPI backend for the white-label cooking app with Supabase database and OpenAI Vision integration.

**Current Version**: Stable build from commit d9e2453

## Features

- **Recipe Management**: CRUD operations for recipes with ingredients and nutrition
- **AI Photo Search**: Analyze ingredient photos using OpenAI Vision API
- **Text Search**: Full-text search across recipes
- **Authentication**: Firebase Auth integration with JWT tokens
- **White-label Support**: Chef-specific configurations and theming
- **Database**: Supabase PostgreSQL with real-time capabilities

## Quick Start

### 1. Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your credentials
nano .env
```

Required environment variables:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_KEY`: Your Supabase anon key
- `SUPABASE_SERVICE_KEY`: Your Supabase service role key
- `OPENAI_API_KEY`: Your OpenAI API key
- `FIREBASE_PROJECT_ID`: Your Firebase project ID
- `SECRET_KEY`: Random secret key for JWT signing

### 2. Database Setup

1. Create a new Supabase project at https://supabase.com
2. Run the SQL schema in your Supabase SQL editor:
   ```sql
   -- Copy and paste contents of database_schema.sql
   ```
3. Insert sample data:
   ```sql
   -- Copy and paste contents of sample_data.sql
   ```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Run the Server

```bash
# Development mode
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Or using the main module
python app/main.py
```

The API will be available at:
- **API**: http://localhost:8000
- **Docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## API Endpoints

### Authentication
- `POST /auth/login` - Login with email/password
- `POST /auth/register` - Register new user
- `GET /auth/me` - Get current user info
- `POST /auth/refresh` - Refresh access token

### Recipes
- `GET /recipes` - List recipes with filtering
- `GET /recipes/{id}` - Get single recipe
- `GET /recipes/featured` - Get featured recipes
- `POST /recipes` - Create new recipe (auth required)
- `GET /recipes/chef/{chef_id}/config` - Get chef configuration

### Search
- `POST /search/photo` - Search recipes by ingredient photo
- `GET /search/text` - Search recipes by text query
- `GET /search/suggestions` - Get search suggestions

## Development

### Project Structure

```
backend/
├── app/
│   ├── api/v1/endpoints/     # API route handlers
│   ├── core/                 # Core configuration and security
│   ├── models/               # Database models
│   ├── schemas/              # Pydantic models for validation
│   ├── services/             # Business logic services
│   └── main.py              # FastAPI application
├── database_schema.sql       # Database schema
├── sample_data.sql          # Sample data for testing
└── requirements.txt         # Python dependencies
```

### Testing

```bash
# Install test dependencies
pip install pytest pytest-asyncio httpx

# Run tests
pytest
```

### Code Quality

```bash
# Format code
black app/

# Sort imports
isort app/

# Type checking
mypy app/
```

## Deployment

### Docker (Recommended)

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app/ ./app/
EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Environment Variables for Production

```bash
ENVIRONMENT=production
DEBUG=False
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
```

## White-Label Configuration

Each chef can have their own configuration stored in the `chefs` table:

```json
{
  "theme_config": {
    "primary_color": "#E74C3C",
    "secondary_color": "#F39C12",
    "accent_color": "#27AE60",
    "background_color": "#FFFFFF",
    "text_color": "#2C3E50",
    "font_family": "Inter"
  },
  "social_links": {
    "instagram": "https://instagram.com/chef",
    "website": "https://chef.com"
  }
}
```

## Troubleshooting

### Common Issues

1. **Database Connection Error**
   - Check Supabase URL and keys in `.env`
   - Ensure database schema is created

2. **OpenAI API Error**
   - Verify OpenAI API key
   - Check API usage limits

3. **Firebase Auth Error**
   - Confirm Firebase project ID
   - Check token format and expiration

### Logs

```bash
# View application logs
tail -f app.log

# Debug mode for detailed logs
DEBUG=True python app/main.py
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
