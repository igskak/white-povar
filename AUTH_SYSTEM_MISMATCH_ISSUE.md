# 🚨 CRITICAL: Authentication System Mismatch

## The Problem

**Your frontend and backend are using DIFFERENT authentication systems!**

### Frontend (Flutter):
```dart
// frontend/lib/features/auth/services/auth_service.dart
final SupabaseClient _supabase = Supabase.instance.client;
```
✅ Uses **Supabase Auth**
- Generates Supabase JWT tokens
- Token format: Supabase-specific JWT
- Issuer: `https://your-project.supabase.co/auth/v1`

### Backend (FastAPI):
```python
# backend/app/core/security.py
class FirebaseAuth:
    """Firebase Authentication service for token verification"""
```
❌ Expects **Firebase Auth**
- Expects Firebase ID tokens
- Token format: Firebase-specific JWT
- Issuer: `https://securetoken.google.com/{project_id}`

---

## Why This Causes 401 Errors

1. **Frontend sends Supabase token** → `Authorization: Bearer <supabase_jwt>`
2. **Backend tries to verify as Firebase token** → Fails because:
   - Different issuer
   - Different signing keys
   - Different token structure
3. **Backend returns 401 Unauthorized** ❌

---

## 🎯 Solution Options

### **Option 1: Use Supabase Auth Everywhere** ⭐ **RECOMMENDED**

**Pros:**
- ✅ You're already using Supabase for database
- ✅ Simpler - one system for everything
- ✅ Supabase has built-in RLS (Row Level Security)
- ✅ Less configuration needed
- ✅ Better integration with Supabase features

**Cons:**
- ❌ Need to update backend auth verification

**Changes needed:**
1. Update backend to verify Supabase JWTs instead of Firebase tokens
2. Use Supabase JWT secret for verification
3. Update auth middleware

---

### **Option 2: Use Firebase Auth Everywhere**

**Pros:**
- ✅ Backend already configured for Firebase
- ✅ Firebase has good Flutter SDK
- ✅ No backend changes needed

**Cons:**
- ❌ Need to replace Supabase Auth in frontend
- ❌ More complex - two separate systems (Firebase for auth, Supabase for DB)
- ❌ Additional service to manage
- ❌ Potential cost for Firebase Auth

**Changes needed:**
1. Replace Supabase Auth with Firebase Auth in Flutter
2. Update all auth-related code in frontend
3. Configure Firebase project

---

### **Option 3: Hybrid - Supabase Auth with Firebase Compatibility**

**Pros:**
- ✅ Keep using Supabase
- ✅ Minimal backend changes

**Cons:**
- ❌ Complex configuration
- ❌ Not recommended by either platform

---

## 📋 Recommended Action Plan

### **Go with Option 1: Supabase Auth Everywhere**

#### Step 1: Update Backend Auth Verification

Replace Firebase auth with Supabase JWT verification:

```python
# backend/app/core/security.py

class SupabaseAuth:
    """Supabase Authentication service for token verification"""
    
    def __init__(self):
        self.jwt_secret = settings.supabase_jwt_secret
        self.issuer = settings.supabase_url
    
    async def verify_token(self, token: str) -> Dict[str, Any]:
        """
        Verify Supabase JWT token and return user claims
        
        Args:
            token: Supabase JWT token
            
        Returns:
            Dict with user claims (sub, email, etc.)
            
        Raises:
            ValueError: If token is invalid
        """
        try:
            # Decode and verify the token
            decoded_token = jwt.decode(
                token,
                self.jwt_secret,
                algorithms=['HS256'],  # Supabase uses HS256
                audience='authenticated',
                issuer=self.issuer,
                options={
                    'verify_exp': True,
                    'verify_iat': True,
                    'verify_aud': True,
                    'verify_iss': True
                }
            )
            
            return decoded_token
            
        except jwt.ExpiredSignatureError:
            raise ValueError("Token has expired")
        except jwt.JWTClaimsError as e:
            raise ValueError(f"Invalid token claims: {str(e)}")
        except Exception as e:
            raise ValueError(f"Token verification failed: {str(e)}")

# Global instance
supabase_auth = SupabaseAuth()

def get_auth_service():
    """Get appropriate auth service based on environment"""
    if settings.environment == "development" and settings.debug:
        return MockAuth()
    else:
        return supabase_auth  # Changed from firebase_auth
```

#### Step 2: Update Settings

```python
# backend/app/core/settings.py

class Settings(BaseSettings):
    # ... existing settings ...
    
    # Supabase Auth settings
    supabase_url: str = os.getenv("SUPABASE_URL", "")
    supabase_anon_key: str = os.getenv("SUPABASE_ANON_KEY", "")
    supabase_service_key: str = os.getenv("SUPABASE_SERVICE_KEY", "")
    supabase_jwt_secret: str = os.getenv("SUPABASE_JWT_SECRET", "")
    
    # Remove or deprecate Firebase settings
    # firebase_project_id: str = os.getenv("FIREBASE_PROJECT_ID", "")
```

#### Step 3: Update Environment Variables

Add to `.env`:
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_KEY=your_service_key
SUPABASE_JWT_SECRET=your_jwt_secret
```

**Where to find JWT secret:**
1. Go to Supabase Dashboard
2. Settings → API
3. Copy "JWT Secret"

#### Step 4: Update Auth Endpoint

```python
# backend/app/api/v1/endpoints/auth.py

async def verify_firebase_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> User:
    """Verify Supabase JWT token and return user info"""  # Updated docstring
    token = credentials.credentials

    try:
        # Get auth service (Supabase or Mock for development)
        auth_service = get_auth_service()

        # Verify the token
        decoded_token = await auth_service.verify_token(token)

        # Extract user information from token
        # Supabase uses 'sub' for user ID, not 'uid'
        user_id = decoded_token.get('sub') or decoded_token.get('user_id', 'unknown')
        email = decoded_token.get('email', 'unknown@example.com')
        
        # ... rest of code
```

#### Step 5: Test

1. Login to the app
2. Check that recipes load without 401 errors
3. Verify subscription features work
4. Test all authenticated endpoints

---

## 🧪 Quick Test to Confirm the Issue

Add this logging to see the token mismatch:

### Frontend:
```dart
// frontend/lib/features/recipes/services/recipe_service.dart
Future<Map<String, String>> _getAuthHeaders() async {
  final token = await _authService.getIdToken();
  if (token != null) {
    // Decode the token to see what it contains
    final parts = token.split('.');
    if (parts.length == 3) {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      print('🔑 Token payload: $payload');
    }
  }
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}
```

### Backend:
```python
# backend/app/api/v1/endpoints/auth.py
async def verify_firebase_token(...):
    token = credentials.credentials
    
    # Decode without verification to see what's inside
    import base64
    import json
    parts = token.split('.')
    if len(parts) == 3:
        payload = base64.urlsafe_b64decode(parts[1] + '==')
        logger.info(f"🔑 Token payload: {payload}")
    
    # ... rest of code
```

**Look for:**
- Supabase token will have `"iss": "https://your-project.supabase.co/auth/v1"`
- Firebase token would have `"iss": "https://securetoken.google.com/..."`

---

## 📊 Summary

**Current State:**
- ❌ Frontend: Supabase Auth
- ❌ Backend: Firebase Auth
- ❌ Result: 401 errors

**Target State:**
- ✅ Frontend: Supabase Auth
- ✅ Backend: Supabase Auth
- ✅ Result: Authentication works!

**Next Steps:**
1. Implement Option 1 (Supabase Auth everywhere)
2. Update backend auth verification
3. Test thoroughly
4. Deploy

---

**This is why you were getting 401 errors even though you were logged in - the tokens are incompatible!**

