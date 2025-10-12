# 🔐 Supabase JWT Secret Setup

## ❌ Current Error

```
Token verification failed: Invalid token: Signature verification failed.
```

**Cause:** The backend is using the wrong secret to verify Supabase JWT tokens.

---

## 🎯 Solution: Add SUPABASE_JWT_SECRET Environment Variable

### **Step 1: Find Your Supabase JWT Secret**

1. Go to your **Supabase Dashboard**: https://supabase.com/dashboard
2. Select your project
3. Go to **Settings** (gear icon in sidebar)
4. Click **API** in the settings menu
5. Scroll down to **JWT Settings** section
6. Copy the **JWT Secret** value

**It looks like this:**
```
your-super-secret-jwt-token-with-at-least-32-characters-long
```

**⚠️ Important:** This is different from:
- ❌ `supabase_key` (anon key)
- ❌ `supabase_service_key` (service role key)
- ✅ `JWT Secret` (used to sign/verify tokens)

---

### **Step 2: Add to Environment Variables**

#### **For Local Development:**

Add to your `.env` file:
```bash
SUPABASE_JWT_SECRET=your-jwt-secret-here
```

#### **For Production (Render.com):**

1. Go to your Render dashboard
2. Select your backend service
3. Go to **Environment** tab
4. Click **Add Environment Variable**
5. Add:
   - **Key:** `SUPABASE_JWT_SECRET`
   - **Value:** `your-jwt-secret-here` (paste the JWT secret from Supabase)
6. Click **Save Changes**
7. Render will automatically redeploy

---

### **Step 3: Verify It Works**

After adding the environment variable and redeploying:

1. **Check backend logs** for:
   ```
   🔐 SupabaseAuth initialized with JWT secret: custom
   ```
   (If it says `service_key`, the env var wasn't set correctly)

2. **Test authentication:**
   - Login to your app
   - Try to view recipes
   - Should work without "Signature verification failed" error ✅

---

## 🔍 How JWT Verification Works

### **Before (Wrong):**
```python
# Using service key to verify tokens ❌
jwt_secret = settings.supabase_service_key
```

**Problem:** Service key is NOT the same as JWT secret!

### **After (Correct):**
```python
# Using actual JWT secret ✅
jwt_secret = settings.supabase_jwt_secret
```

**How it works:**
1. User logs in via Supabase Auth
2. Supabase signs JWT token with **JWT Secret**
3. Frontend sends token to backend
4. Backend verifies token using **same JWT Secret**
5. If signature matches → ✅ Token is valid
6. If signature doesn't match → ❌ "Signature verification failed"

---

## 📊 Environment Variables Summary

| Variable | Purpose | Where to Find |
|----------|---------|---------------|
| `SUPABASE_URL` | Supabase project URL | Dashboard → Settings → API → Project URL |
| `SUPABASE_KEY` | Anon/public key | Dashboard → Settings → API → Project API keys → anon public |
| `SUPABASE_SERVICE_KEY` | Service role key | Dashboard → Settings → API → Project API keys → service_role |
| `SUPABASE_JWT_SECRET` | JWT signing secret | Dashboard → Settings → API → JWT Settings → JWT Secret |

---

## 🚨 Security Note

**Keep your JWT Secret safe!**
- ❌ Don't commit it to git
- ❌ Don't share it publicly
- ✅ Store it in environment variables only
- ✅ Use different secrets for dev/staging/production

If your JWT secret is compromised:
1. Go to Supabase Dashboard → Settings → API
2. Click **Generate new JWT secret**
3. Update all your environment variables
4. All existing tokens will be invalidated (users need to re-login)

---

## 🧪 Testing

### **Test 1: Check if JWT secret is set**

```bash
# SSH into your Render instance or check logs
echo $SUPABASE_JWT_SECRET
# Should output your JWT secret (not empty)
```

### **Test 2: Verify token manually**

You can test token verification using Python:

```python
from jose import jwt

token = "your-user-token-here"
jwt_secret = "your-jwt-secret-here"

try:
    decoded = jwt.decode(token, jwt_secret, algorithms=['HS256'])
    print("✅ Token verified successfully!")
    print(f"User ID: {decoded.get('sub')}")
except Exception as e:
    print(f"❌ Verification failed: {e}")
```

---

## 📝 Checklist

- [ ] Found JWT Secret in Supabase Dashboard
- [ ] Added `SUPABASE_JWT_SECRET` to local `.env` file
- [ ] Added `SUPABASE_JWT_SECRET` to Render environment variables
- [ ] Redeployed backend (Render does this automatically)
- [ ] Checked logs for "SupabaseAuth initialized with JWT secret: custom"
- [ ] Tested login and recipe viewing
- [ ] No more "Signature verification failed" errors

---

## 🎉 Expected Result

**Before:**
```
❌ Token verification failed: Invalid token: Signature verification failed.
❌ 401 Unauthorized
```

**After:**
```
✅ Token verified successfully for user: <user-id>
✅ 200 OK
```

---

## 🆘 Troubleshooting

### **Still getting "Signature verification failed"?**

1. **Check the JWT secret is correct:**
   - Copy it again from Supabase Dashboard
   - Make sure there are no extra spaces or newlines

2. **Check environment variable is set:**
   - In Render, verify the variable is listed
   - Check the backend logs for the initialization message

3. **Restart the backend:**
   - In Render, click "Manual Deploy" → "Clear build cache & deploy"

4. **Check token is from the right Supabase project:**
   - Make sure frontend is using the same Supabase project
   - Check `SUPABASE_URL` matches in both frontend and backend

### **Getting 404 for /subscription/status?**

The frontend is calling `/subscription/status` but should call `/api/v1/subscription/status`.
This is a separate issue - the frontend needs to be updated to use the correct endpoint.

---

**Once you add the JWT secret, authentication should work perfectly!** 🎉

