# Premium Content Access System - Frontend Implementation

## Overview
This document describes the Flutter frontend implementation of the premium content access system for the White Povar recipe application.

## Implementation Status

### ✅ Completed Components

#### 1. **Recipe Model Update**
- Added `isPremium` field to Recipe model
- Updated `fromJson` to parse `is_premium` from API
- Updated `toJson` to include `is_premium`
- Added to Equatable props for proper comparison

**File:** `frontend/lib/features/recipes/models/recipe.dart`

#### 2. **Subscription Models**
Created comprehensive subscription models:

**File:** `frontend/lib/features/subscription/models/subscription.dart`

- `SubscriptionTier` enum (free, premium)
- `SubscriptionStatus` enum (active, expired, cancelled, trial)
- `UserSubscriptionInfo` - User's subscription details
- `SubscriptionFeatures` - Feature flags for each tier
- `SubscriptionStatusResponse` - Complete status from API
- `UpgradePrompt` - Upgrade messaging
- `PremiumAccessCheck` - Access validation result

#### 3. **Subscription Service**
HTTP service for subscription API calls:

**File:** `frontend/lib/features/subscription/services/subscription_service.dart`

Methods:
- `getSubscriptionStatus()` - Get user's subscription status
- `checkPremiumAccess()` - Check access for specific feature
- `getAvailableFeatures()` - Get feature list
- `getUpgradePrompt()` - Get upgrade messaging
- `getSubscriptionTiers()` - Get tier information
- `grantPremiumAccess()` - Testing: grant premium
- `revokePremiumAccess()` - Testing: revoke premium
- `updateSubscription()` - Admin: update subscription

#### 4. **Subscription State Management**
Riverpod-based state management:

**Files:**
- `frontend/lib/features/subscription/models/subscription_state.dart`
- `frontend/lib/features/subscription/providers/subscription_provider.dart`

**Providers:**
- `subscriptionProvider` - Main subscription state
- `isPremiumProvider` - Quick premium check
- `subscriptionFeaturesProvider` - Current features
- `subscriptionTierProvider` - Current tier

**State Methods:**
- `loadSubscriptionStatus()` - Load from API
- `refresh()` - Refresh status
- `checkPremiumAccess()` - Check specific feature
- `getUpgradePrompt()` - Get upgrade prompt
- `grantPremiumAccess()` - Testing helper
- `revokePremiumAccess()` - Testing helper

#### 5. **UI Components**

**Premium Badge Widget**
**File:** `frontend/lib/features/subscription/widgets/premium_badge.dart`

- `PremiumBadge` - Badge for premium content
- `PremiumOverlay` - Overlay for locked content
- `PremiumIndicator` - Small indicator for lists

**Upgrade Prompt Dialog**
**File:** `frontend/lib/features/subscription/widgets/upgrade_prompt_dialog.dart`

- `UpgradePromptDialog` - Main dialog
- Static methods for different prompt types:
  - `showAIFeaturePrompt()`
  - `showPremiumRecipePrompt()`
  - `showAdvancedSearchPrompt()`

**Subscription Screen**
**File:** `frontend/lib/features/subscription/screens/subscription_screen.dart`

- Full subscription management screen
- Shows current status and features
- Upgrade/manage buttons
- Testing controls (debug mode only)

## Usage Examples

### 1. Check if User is Premium

```dart
// In a widget
final isPremium = ref.watch(isPremiumProvider);

if (isPremium) {
  // Show premium content
} else {
  // Show upgrade prompt
}
```

### 2. Display Premium Badge on Recipe

```dart
// In recipe card/list item
if (recipe.isPremium) {
  PremiumIndicator(isPremium: recipe.isPremium)
}
```

### 3. Lock Premium Content

```dart
PremiumOverlay(
  isPremium: recipe.isPremium,
  hasAccess: ref.watch(isPremiumProvider),
  onTap: () {
    UpgradePromptDialog.showPremiumRecipePrompt(context);
  },
  child: RecipeCard(recipe: recipe),
)
```

### 4. Gate AI Features

```dart
// Before calling AI feature
final features = ref.watch(subscriptionFeaturesProvider);

if (!features.aiRecipeGeneration) {
  await UpgradePromptDialog.showAIFeaturePrompt(context);
  return;
}

// Proceed with AI feature
```

### 5. Load Subscription Status

```dart
// In initState or when user logs in
@override
void initState() {
  super.initState();
  Future.microtask(() {
    ref.read(subscriptionProvider.notifier).loadSubscriptionStatus();
  });
}
```

## Integration Steps

### Step 1: Update Recipe List UI

Add premium indicators to recipe cards:

```dart
// In recipe_card.dart or similar
Stack(
  children: [
    // Existing recipe card content
    RecipeImage(recipe: recipe),
    
    // Add premium badge
    if (recipe.isPremium)
      Positioned(
        top: 8,
        right: 8,
        child: PremiumBadge(size: 24),
      ),
  ],
)
```

### Step 2: Update Recipe Detail Screen

Add access control for premium recipes:

```dart
// In recipe_detail_screen.dart
@override
Widget build(BuildContext context) {
  final isPremium = ref.watch(isPremiumProvider);
  
  return PremiumOverlay(
    isPremium: recipe.isPremium,
    hasAccess: isPremium,
    onTap: () {
      UpgradePromptDialog.showPremiumRecipePrompt(context);
    },
    child: _buildRecipeContent(),
  );
}
```

### Step 3: Gate AI Features

Update AI feature buttons/screens:

```dart
// In ai_recipe_generator_screen.dart
Future<void> _generateRecipe() async {
  final features = ref.read(subscriptionFeaturesProvider);
  
  if (!features.aiRecipeGeneration) {
    await UpgradePromptDialog.showAIFeaturePrompt(context);
    return;
  }
  
  // Proceed with generation
  // ...
}
```

### Step 4: Add Subscription to Navigation

Add subscription screen to router:

```dart
// In router configuration
GoRoute(
  path: '/subscription',
  builder: (context, state) => const SubscriptionScreen(),
),
```

### Step 5: Add Subscription Link to Profile/Settings

```dart
// In profile_screen.dart or settings_screen.dart
ListTile(
  leading: const Icon(Icons.workspace_premium),
  title: const Text('Subscription'),
  trailing: ref.watch(isPremiumProvider)
      ? const PremiumBadge(size: 20)
      : null,
  onTap: () => context.push('/subscription'),
),
```

### Step 6: Handle 403 Errors from API

Add error handling for premium access denied:

```dart
// In API service or error handler
if (response.statusCode == 403) {
  final error = jsonDecode(response.body);
  
  if (error['error_code'] == 'PREMIUM_ACCESS_REQUIRED') {
    final upgradePrompt = UpgradePrompt.fromJson(
      error['upgrade_prompt'] ?? {}
    );
    
    if (context.mounted) {
      await UpgradePromptDialog.show(context, upgradePrompt);
    }
    return;
  }
}
```

### Step 7: Initialize Subscription on App Start

```dart
// In main app widget or auth listener
ref.listen(authProvider, (previous, next) {
  if (next.isAuthenticated) {
    // Load subscription when user logs in
    ref.read(subscriptionProvider.notifier).loadSubscriptionStatus();
  }
});
```

## Testing

### Manual Testing

1. **Test Free User Flow:**
   - Log in as a user
   - Verify only basic recipes are visible
   - Try to access AI features → should show upgrade prompt
   - Try to access premium recipe → should show locked overlay

2. **Test Premium User Flow:**
   - Use testing controls to grant premium
   - Verify all recipes are visible
   - Verify AI features are accessible
   - Verify premium badge shows on subscription screen

3. **Test Upgrade Prompts:**
   - As free user, tap on locked content
   - Verify upgrade dialog appears
   - Verify features list is correct
   - Verify "Upgrade" button navigates correctly

### Testing Controls

In debug mode, the subscription screen includes testing buttons:
- "Grant Premium (30 days)" - Grants premium access
- "Revoke Premium" - Removes premium access

These buttons call the backend testing endpoints and refresh the subscription status.

## Next Steps (Remaining Tasks)

### 1. Update Search UI
- Filter search results based on subscription
- Show premium badge in search results
- Handle premium recipe taps in search

### 2. Update Navigation
- Add subscription link to main menu
- Show premium badge for premium users
- Add quick access to upgrade

### 3. Error Handling
- Implement global 403 error handler
- Show upgrade prompts from API errors
- Handle network errors gracefully

### 4. Payment Integration
- Integrate LiqPay payment flow
- Handle payment success/failure
- Update subscription after payment

### 5. Polish & UX
- Add animations to premium badges
- Improve upgrade dialog design
- Add subscription benefits page
- Implement trial period UI

## File Structure

```
frontend/lib/features/subscription/
├── models/
│   ├── subscription.dart           # All subscription models
│   └── subscription_state.dart     # State model
├── services/
│   └── subscription_service.dart   # API service
├── providers/
│   └── subscription_provider.dart  # Riverpod providers
├── widgets/
│   ├── premium_badge.dart          # Badge components
│   └── upgrade_prompt_dialog.dart  # Upgrade dialog
└── screens/
    └── subscription_screen.dart    # Subscription page
```

## Dependencies

No new dependencies required! Uses existing packages:
- `flutter_riverpod` - State management
- `http` - API calls
- `go_router` - Navigation
- `equatable` - Model comparison

## Notes

- All premium checks are done on the backend for security
- Frontend only shows/hides UI based on subscription status
- Subscription status is cached in Riverpod state
- Refresh subscription status after login/payment
- Testing controls only visible in debug mode

