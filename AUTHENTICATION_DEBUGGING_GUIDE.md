# 🔍 Authentication Debugging Guide

## Current Error Analysis

```
Token verification failed: Invalid token: Signature verification failed.
INFO:     86.49.237.147:0 - "POST /api/v1/auth/sync HTTP/1.1" 401 Unauthorized
INFO:     86.49.237.147:0 - "GET /api/v1/recipes HTTP/1.1" 307 Temporary Redirect
INFO:     86.49.237.147:0 - "GET /subscription/status HTTP/1.1" 404 Not Found
INFO:     86.49.237.147:0 - "GET /api/v1/recipes/ HTTP/1.1" 403 Forbidden
```

---

## 🎯 Root Cause: JWT Secret Not Set

The error **"Signature verification failed"** means:

❌ **The backend doesn't have the correct JWT secret to verify Supabase tokens**

---

## ✅ Solution: Add SUPABASE_JWT_SECRET to Render

### **Step 1: Get Your JWT Secret from Supabase**

1. Go to: https://supabase.com/dashboard
2. Select your project: **qnlfvpqmkmbvzmzqgjpo** (from your frontend config)
3. Click **Settings** → **API**
4. Scroll to **JWT Settings**
5. Copy the **JWT Secret** value

**Example of what it looks like:**
```
super-secret-jwt-token-with-at-least-32-characters-1234567890
```

---

### **Step 2: Add to Render Environment Variables**

1. Go to: https://dashboard.render.com
2. Find your backend service: **white-povar** or **White Povar API**
3. Click on the service
4. Go to **Environment** tab (left sidebar)
5. Click **Add Environment Variable** button
6. Enter:
   - **Key:** `SUPABASE_JWT_SECRET`
   - **Value:** (paste the JWT secret from Supabase)
7. Click **Save Changes**

**Render will automatically trigger a redeploy** (~3-5 minutes)

---

### **Step 3: Verify Deployment**

After deployment completes, check the logs for:

```
🔐 SupabaseAuth initialized with JWT secret: custom
```

**If you see:**
- ✅ `JWT secret: custom` → JWT secret is set correctly
- ❌ `JWT secret: service_key` → JWT secret NOT set (using fallback)
- ❌ `NO JWT SECRET SET!` → No secret configured at all

---

## 🔍 Understanding the Errors

### **1. "Signature verification failed" (401)**
```
Token verification failed: Invalid token: Signature verification failed.
```

**Cause:** Backend can't verify the token signature
**Why:** Missing or wrong JWT secret
**Fix:** Add correct `SUPABASE_JWT_SECRET` to Render

---

### **2. "307 Temporary Redirect"**
```
INFO: "GET /api/v1/recipes HTTP/1.1" 307 Temporary Redirect
```

**Cause:** FastAPI redirects `/api/v1/recipes` → `/api/v1/recipes/`
**Why:** Frontend calls without trailing slash
**Impact:** ⚠️ This is NORMAL and not an error
**Fix:** None needed (or update frontend to use trailing slash)

---

### **3. "404 Not Found" on /subscription/status**
```
INFO: "GET /subscription/status HTTP/1.1" 404 Not Found
```

**Cause:** Frontend calling wrong endpoint
**Why:** Should be `/api/v1/subscription/status` not `/subscription/status`
**Impact:** ⚠️ Subscription status check fails
**Fix:** Update frontend to use correct endpoint (separate issue)

---

### **4. "403 Forbidden"**
```
INFO: "GET /api/v1/recipes/ HTTP/1.1" 403 Forbidden
```

**Cause:** User authentication succeeded but authorization failed
**Why:** Either:
  - User doesn't exist in database
  - User missing subscription fields
  - Premium access check failing
**Fix:** Already fixed in commit `8b15f20` (sets default subscription tier)

---

## 🧪 Testing After Fix

### **Test 1: Check Logs**

After adding JWT secret and redeploying, you should see:

```
✅ GOOD:
🔐 SupabaseAuth initialized with JWT secret: custom
🔍 Verifying token: eyJhbGciOiJIUzI1NiI...
🔑 Using JWT secret: super-secr...
✅ Token verified successfully for user: <user-id>
```

```
❌ BAD:
🔐 SupabaseAuth initialized with JWT secret: service_key
❌ JWT Error: Signature verification failed
```

---

### **Test 2: Login and View Recipes**

1. Open your app
2. Login with email/password
3. Try to view recipes
4. Should work without errors ✅

---

### **Test 3: Check Backend Logs**

Look for these patterns:

**Success:**
```
✅ Token verified successfully for user: abc-123-def
✅ Created new user with free tier: abc-123-def
INFO: "GET /api/v1/recipes/ HTTP/1.1" 200 OK
```

**Failure:**
```
❌ JWT Error: Signature verification failed
INFO: "GET /api/v1/recipes/ HTTP/1.1" 401 Unauthorized
```

---

## 📋 Checklist

- [ ] **Found JWT Secret** in Supabase Dashboard → Settings → API
- [ ] **Added to Render** as `SUPABASE_JWT_SECRET` environment variable
- [ ] **Saved changes** in Render (triggers auto-deploy)
- [ ] **Waited for deployment** to complete (~5 minutes)
- [ ] **Checked logs** for "JWT secret: custom"
- [ ] **Tested login** in the app
- [ ] **Verified recipes load** without errors

---

## 🆘 Still Not Working?

### **Double-check the JWT Secret**

1. **Is it the right secret?**
   - Go back to Supabase Dashboard → Settings → API
   - Copy the JWT Secret again (not the anon key or service key!)
   - Make sure there are no extra spaces or newlines

2. **Is it set in Render?**
   - Go to Render Dashboard → Your Service → Environment
   - Look for `SUPABASE_JWT_SECRET` in the list
   - Click the eye icon to verify the value

3. **Did Render redeploy?**
   - Check the "Events" tab in Render
   - Should show "Deploy succeeded" after you added the variable
   - If not, click "Manual Deploy" → "Deploy latest commit"

---

### **Check Supabase Project ID**

Your frontend config shows:
```dart
supabaseUrl: 'https://qnlfvpqmkmbvzmzqgjpo.supabase.co'
```

Make sure you're getting the JWT secret from the **same project** (`qnlfvpqmkmbvzmzqgjpo`).

---

### **Verify Token Format**

The token from Supabase should look like:
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

It has 3 parts separated by dots (`.`):
1. Header (algorithm and type)
2. Payload (user data)
3. Signature (verified with JWT secret)

---

## 🎯 Expected Flow After Fix

1. **User logs in** → Supabase Auth returns JWT token
2. **Frontend sends token** → `Authorization: Bearer <token>`
3. **Backend receives token** → Extracts from header
4. **Backend verifies token** → Uses `SUPABASE_JWT_SECRET`
5. **Signature matches** → ✅ Token is valid
6. **User authenticated** → Returns user data
7. **Recipes load** → 200 OK

---

## 📞 Quick Reference

| Issue | Cause | Fix |
|-------|-------|-----|
| Signature verification failed | No JWT secret | Add `SUPABASE_JWT_SECRET` to Render |
| 307 Redirect | Trailing slash | Normal behavior, ignore |
| 404 on /subscription/status | Wrong endpoint | Update frontend (separate issue) |
| 403 Forbidden | Missing subscription | Already fixed in commit 8b15f20 |

---

**The #1 thing you need to do: Add `SUPABASE_JWT_SECRET` to Render!** 🔑

