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
- **Authentication**: Email/password login with social auth support (Google, Apple)
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

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   # For web
   flutter run -d chrome --web-port 3000

   # For mobile (with device/emulator connected)
   flutter run
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

## Deployment

### Backend Deployment
The backend can be deployed to any platform that supports Python applications:
- Heroku
- AWS Lambda
- Google Cloud Run
- DigitalOcean App Platform

### Frontend Deployment
The Flutter app can be deployed as:
- **Web**: Static hosting (Netlify, Vercel, Firebase Hosting)
- **Mobile**: App stores (Google Play, Apple App Store)
- **Desktop**: Native desktop applications

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
