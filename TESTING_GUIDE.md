# Premium Subscription System - Testing Guide

## 🎯 Current Status

### ✅ Backend Server
- **Status**: Running on http://localhost:8000
- **API Docs**: http://localhost:8000/docs (opened in browser)
- **Health Check**: http://localhost:8000/health

### ⏳ Database Migrations
**Action Required**: Run the migrations in Supabase SQL Editor

I've opened the Supabase SQL Editor for you. Please:

1. **Copy Migration 1** from the terminal output above (or from `backend/migrations/add_premium_subscription_system.sql`)
2. **Paste in SQL Editor** and click "Run"
3. **Copy Migration 2** from the terminal output above (or from `backend/migrations/mark_sample_premium_recipe.sql`)
4. **Paste in SQL Editor** and click "Run"

## 📋 Testing Checklist

### Step 1: Verify Migrations ✅

After running migrations, check in Supabase:

**Table Editor → users:**
- [ ] New columns exist: `subscription_tier`, `subscription_status`, `subscription_start_date`, `subscription_end_date`
- [ ] All users have `subscription_tier = 'free'`

**Table Editor → recipes:**
- [ ] New column exists: `is_premium`
- [ ] One recipe has `is_premium = true`

**Tables:**
- [ ] `subscriptions` table exists
- [ ] `subscription_events` table exists

### Step 2: Test Backend API 🔧

**Using the API Docs (http://localhost:8000/docs):**

1. **Authenticate First:**
   - Use the `/api/v1/auth/login` endpoint
   - Get your JWT token
   - Click "Authorize" button at top of page
   - Enter: `Bearer YOUR_TOKEN`

2. **Test Subscription Endpoints:**

   **GET /api/v1/subscription/status**
   - Should return your subscription status
   - Expected: `tier: "free"`, `status: "active"`

   **GET /api/v1/subscription/features**
   - Should return available features
   - Expected: `ai_recipe_generation: false` for free users

   **POST /api/v1/subscription/grant-premium**
   - Grant yourself premium for testing
   - Should return success message
   - Check status again - should now be `tier: "premium"`

   **GET /api/v1/subscription/check-access**
   - Check if you have premium access
   - Expected: `has_access: true` after granting premium

3. **Test Recipe Filtering:**

   **GET /api/v1/recipes**
   - As free user: should only see free recipes
   - As premium user: should see all recipes

4. **Test AI Endpoints:**

   **POST /api/v1/ai/recipe-suggestions**
   - As free user: should return 403 with upgrade prompt
   - As premium user: should work normally

### Step 3: Test Frontend 📱

**Start the Flutter app:**

```bash
cd frontend
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_URL=https://qnlfvpqmkmbvzmzqgjpo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

**Test Scenarios:**

1. **Login and Check Subscription:**
   - [ ] Log in to the app
   - [ ] Click menu → Subscription
   - [ ] Should see "Free" tier
   - [ ] Should see "Upgrade to Premium" button

2. **Test Free User Experience:**
   - [ ] Browse recipes - should only see free recipes
   - [ ] Premium recipe should show premium badge
   - [ ] Click AI Assistant button → should show upgrade prompt
   - [ ] Upgrade prompt should have feature list
   - [ ] "Upgrade to Premium" button should navigate to subscription page

3. **Grant Premium (Testing):**
   - [ ] Go to Subscription page
   - [ ] Scroll down to "Testing Controls" section
   - [ ] Click "Grant Premium (30 days)"
   - [ ] Status should update to "Premium"
   - [ ] Premium badge should appear in menu

4. **Test Premium User Experience:**
   - [ ] Browse recipes - should see ALL recipes
   - [ ] Premium recipes should still show premium badge
   - [ ] Click AI Assistant button → should open AI dialog
   - [ ] AI features should work normally

5. **Test UI Elements:**
   - [ ] Premium badge on recipe cards (top-left corner)
   - [ ] Premium badge in recipe detail header
   - [ ] Premium indicator in menu next to "Subscription"
   - [ ] Subscription status card with gradient
   - [ ] Feature list with checkmarks

6. **Revoke Premium (Testing):**
   - [ ] Go to Subscription page
   - [ ] Click "Revoke Premium"
   - [ ] Status should update to "Free"
   - [ ] Premium badge should disappear from menu
   - [ ] AI features should be locked again

## 🧪 API Testing with cURL

If you prefer command-line testing:

```bash
# Get your auth token first
TOKEN="your_jwt_token_here"

# Check subscription status
curl http://localhost:8000/api/v1/subscription/status \
  -H "Authorization: Bearer $TOKEN"

# Grant premium
curl -X POST http://localhost:8000/api/v1/subscription/grant-premium \
  -H "Authorization: Bearer $TOKEN"

# Check features
curl http://localhost:8000/api/v1/subscription/features \
  -H "Authorization: Bearer $TOKEN"

# Try AI endpoint (should fail for free users)
curl -X POST http://localhost:8000/api/v1/ai/recipe-suggestions \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ingredients": ["chicken", "rice"]}'

# Revoke premium
curl -X POST http://localhost:8000/api/v1/subscription/revoke-premium \
  -H "Authorization: Bearer $TOKEN"
```

## 📊 Expected Results

### Free User:
- ✅ Can see free recipes only
- ❌ Cannot access AI features
- ❌ Cannot see premium recipes
- ✅ Sees upgrade prompts
- ✅ Can navigate to subscription page

### Premium User:
- ✅ Can see all recipes (free + premium)
- ✅ Can access all AI features
- ✅ Sees premium badge in UI
- ✅ No upgrade prompts
- ✅ Subscription page shows "Premium" status

## 🐛 Troubleshooting

### Backend Issues:

**"Module not found" errors:**
```bash
cd backend
pip3 install -r requirements.txt
```

**"Database connection failed":**
- Check `.env` file has correct `SUPABASE_URL` and `SUPABASE_SERVICE_KEY`
- Verify Supabase project is running

**"Table does not exist":**
- Run the database migrations in Supabase SQL Editor

### Frontend Issues:

**"Failed to connect to backend":**
- Make sure backend is running on http://localhost:8000
- Check `--dart-define=API_BASE_URL=http://localhost:8000`

**"Subscription status not loading":**
- Check browser console for errors
- Verify you're logged in
- Check network tab for API calls

**"Premium badge not showing":**
- Make sure migrations ran successfully
- Check that recipe has `is_premium = true` in database
- Refresh the app

## ✅ Success Criteria

The system is working correctly if:

1. ✅ Migrations run without errors
2. ✅ Backend API returns subscription status
3. ✅ Free users see only free recipes
4. ✅ Premium users see all recipes
5. ✅ AI features are gated for free users
6. ✅ Upgrade prompts appear correctly
7. ✅ Premium badges display on recipes
8. ✅ Subscription page shows correct status
9. ✅ Testing controls work (grant/revoke)
10. ✅ Navigation to subscription page works

## 📝 Notes

- **Testing Controls**: Only visible in debug mode
- **Premium Duration**: Testing grant gives 30 days
- **Database**: All changes are real - use testing endpoints carefully
- **Payment**: LiqPay integration not yet implemented (future task)

## 🚀 Next Steps After Testing

Once testing is complete:

1. **Deploy to Production:**
   - Run migrations on production database
   - Deploy backend to production server
   - Build and deploy Flutter app

2. **Integrate LiqPay:**
   - Set up LiqPay merchant account
   - Implement payment webhook
   - Add payment UI to subscription page

3. **Add Localization:**
   - Translate UI to Ukrainian
   - Add language switcher

4. **Monitor:**
   - Set up analytics
   - Track subscription conversions
   - Monitor error rates

