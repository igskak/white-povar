# Debugging 401 Authentication Errors

## 🔍 Why You Got 401 Errors (Even Though You Were Logged In)

You mentioned you were logged in but still got 401 errors. Here are the most likely causes:

---

## 🎯 Most Common Causes:

### 1. **Token Expiration** ⏰
**Firebase tokens expire after 1 hour**

**Symptoms:**
- App works fine initially
- After ~1 hour, starts showing 401 errors
- Refreshing the app fixes it temporarily

**Solution:**
The frontend should automatically refresh tokens, but check:

```dart
// frontend/lib/features/auth/services/auth_service.dart
Future<String?> getIdToken() async {
  final user = _supabase.auth.currentUser;
  if (user == null) return null;
  
  // This should automatically refresh if expired
  final session = _supabase.auth.currentSession;
  return session?.accessToken;
}
```

**Fix if needed:**
Add token refresh logic in the auth service.

---

### 2. **Wrong Token Type** 🎫
**Using Supabase token instead of Firebase token**

**The Issue:**
- Your backend expects **Firebase tokens** (verified via Firebase Auth)
- But you're using **Supabase Auth** in the frontend
- Supabase generates its own JWT tokens (not Firebase tokens)

**Check this:**
```dart
// In auth_service.dart - are you using Supabase auth?
await _supabase.auth.signInWithPassword(...)  // ← This creates Supabase tokens

// But backend expects Firebase tokens:
// backend/app/core/security.py - FirebaseAuth class
```

**This is likely THE PROBLEM!** 🚨

Your frontend uses **Supabase Auth**, but your backend is configured to verify **Firebase tokens**. These are incompatible!

---

### 3. **CORS Issues** 🌐
**Browser blocking the Authorization header**

**Symptoms:**
- Works in development
- Fails in production
- Network tab shows missing Authorization header

**Check:**
```python
# backend/app/main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Or specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],  # ← Must include Authorization
)
```

---

### 4. **Environment Mismatch** 🔧
**Development vs Production auth settings**

**Check:**
```python
# backend/app/core/security.py
def get_auth_service():
    if settings.environment == "development" and settings.debug:
        return MockAuth()  # ← Development uses mock auth
    else:
        return firebase_auth  # ← Production uses Firebase
```

If your production environment is set to development mode, it might be using MockAuth.

---

## 🔧 How to Debug:

### Step 1: Check What Token You're Sending

Add logging to the frontend:

```dart
// frontend/lib/features/recipes/services/recipe_service.dart
Future<Map<String, String>> _getAuthHeaders() async {
  final token = await _authService.getIdToken();
  print('🔑 Token: ${token?.substring(0, 20)}...'); // First 20 chars
  print('🔑 Token length: ${token?.length}');
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}
```

### Step 2: Check Backend Token Verification

Add logging to the backend:

```python
# backend/app/api/v1/endpoints/auth.py
async def verify_firebase_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> User:
    token = credentials.credentials
    logger.info(f"🔑 Received token: {token[:20]}...")  # First 20 chars
    logger.info(f"🔑 Token length: {len(token)}")
    
    try:
        auth_service = get_auth_service()
        logger.info(f"🔧 Using auth service: {type(auth_service).__name__}")
        
        decoded_token = await auth_service.verify_token(token)
        logger.info(f"✅ Token verified successfully for user: {decoded_token.get('uid')}")
        # ... rest of code
```

### Step 3: Check Backend Logs

Look for these patterns:
- `Token verification failed: ...` - Token is invalid
- `Invalid token: key ID not found` - Wrong token type (Supabase vs Firebase)
- `Token expired` - Need to refresh token
- `Authentication error: ...` - General auth failure

---

## 🎯 **MOST LIKELY SOLUTION:**

### **You're Using Supabase Auth, But Backend Expects Firebase Auth**

**Option A: Switch Backend to Supabase Auth** (Recommended)

1. Update backend to verify Supabase tokens instead of Firebase tokens
2. Use Supabase JWT verification
3. Simpler since you're already using Supabase for database

**Option B: Switch Frontend to Firebase Auth**

1. Replace Supabase Auth with Firebase Auth in Flutter
2. Keep backend as-is
3. More complex migration

**Option C: Use Supabase Auth with Custom JWT**

1. Configure Supabase to issue custom JWTs
2. Update backend to verify Supabase JWTs
3. Middle ground solution

---

## 🧪 Quick Test:

### Test if authentication is working at all:

```bash
# Get your token from the app (add print statement)
TOKEN="your_actual_token_here"

# Test the /auth/me endpoint
curl -X GET "https://your-api.com/api/v1/auth/me" \
  -H "Authorization: Bearer $TOKEN"

# Should return your user info if token is valid
# Should return 401 if token is invalid
```

---

## 📊 Next Steps:

1. **Check which auth system you're actually using:**
   - Frontend: Supabase Auth or Firebase Auth?
   - Backend: Expecting Firebase tokens or Supabase tokens?

2. **Add logging** to see what's happening

3. **Test with curl** to isolate frontend vs backend issues

4. **Check token expiration** - does it work initially then fail?

5. **Verify CORS settings** - are headers being sent?

---

## 🚨 Action Items:

1. Add the logging code above to both frontend and backend
2. Try to reproduce the 401 error
3. Check the logs to see:
   - Is token being sent?
   - What type of token is it?
   - What error is the backend returning?
4. Share the logs and we can pinpoint the exact issue

---

**Most likely, you need to align your auth systems - either use Supabase Auth everywhere or Firebase Auth everywhere. Right now they're mismatched!**

