# Database Migration Instructions

## ✅ Step-by-Step Guide

I've opened the Supabase SQL Editor for you in your browser. Follow these steps:

### Migration 1: Add Premium Subscription System

1. **In the SQL Editor that just opened**, paste the following SQL:
   - Copy the entire contents of `backend/migrations/add_premium_subscription_system.sql`
   - Or use the command below to view it:
   ```bash
   cat backend/migrations/add_premium_subscription_system.sql
   ```

2. **Click "Run"** (or press Cmd/Ctrl + Enter)

3. **Wait for success message** - You should see:
   ```
   Migration completed successfully!
   Users with free tier: [number]
   Total recipes: [number]
   Premium recipes: 0
   ```

### Migration 2: Mark Sample Premium Recipe

1. **Create a new query** in the SQL Editor

2. **Paste the following SQL**:
   - Copy the entire contents of `backend/migrations/mark_sample_premium_recipe.sql`
   - Or use the command below to view it:
   ```bash
   cat backend/migrations/mark_sample_premium_recipe.sql
   ```

3. **Click "Run"**

4. **Check the output** - You should see:
   ```
   Marked recipe as premium:
   ID: [uuid]
   Title: [recipe name]
   ```

## Quick Copy Commands

### View Migration 1:
```bash
cd backend
cat migrations/add_premium_subscription_system.sql
```

### View Migration 2:
```bash
cd backend
cat migrations/mark_sample_premium_recipe.sql
```

## Verification

After running both migrations, verify in Supabase:

1. Go to **Table Editor** → **users**
   - Check for new columns: `subscription_tier`, `subscription_status`, etc.
   - All users should have `subscription_tier = 'free'`

2. Go to **Table Editor** → **recipes**
   - Check for new column: `is_premium`
   - One recipe should have `is_premium = true`

3. Check new tables exist:
   - `subscriptions`
   - `subscription_events`

## Troubleshooting

**If you get an error about missing tables:**
- Make sure your database schema is up to date
- Check that `users` and `recipes` tables exist

**If you get duplicate object errors:**
- This is normal! The migration uses `IF NOT EXISTS` clauses
- It means some objects already exist, which is fine

**If you get permission errors:**
- Make sure you're logged into the correct Supabase project
- Check that you have admin access to the project

## Next Steps

After migrations are complete:
1. ✅ Start the backend server
2. ✅ Start the frontend app
3. ✅ Test the subscription system

