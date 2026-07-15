# Mobile commerce: RevenueCat (COM-02)

RevenueCat is the managed provider selected for the MVP. Its public iOS and
Android SDK keys may be embedded in their respective native apps when COM-03
starts purchase handling; the RevenueCat webhook authorization value is a
server secret and must exist only as `REVENUECAT_WEBHOOK_AUTHORIZATION`.

The Flutter adapter currently loads only StoreKit/Play Billing product display
data. It first receives tenant-scoped store IDs from `GET /api/v1/commerce/store-products`, then asks the native store for localized prices. Checkout, transaction completion, restore and manage-subscription remain COM-03.

## Sandbox checklist

1. Create App Store Connect and Play Console sandbox applications for every
   white-label app and create the monthly/annual subscription product IDs.
2. Configure matching RevenueCat apps, products and offerings. Set each
   RevenueCat app's App User ID to the authenticated White Povar user UUID.
3. Insert active `store_product_mappings` for the tenant after products have
   passed store review. Do not put IDs, prices or offer eligibility in
   `BrandConfig` or a Flutter `--dart-define`.
4. Set a random webhook Authorization value in RevenueCat and the Render
   environment as `REVENUECAT_WEBHOOK_AUTHORIZATION`. Point the webhook to
   `POST /api/v1/commerce/webhooks/revenuecat`.
5. Exercise initial purchase, renewal, billing issue, expiration, refund,
   duplicate delivery and an older event after a newer one. Confirm only
   `commerce_entitlements` grants access.

The webhook calls the transactional `process_revenuecat_event` RPC. It first
deduplicates `(provider, event_key)` in `purchase_events`; unknown products are
recorded as rejected; and older events cannot overwrite a newer entitlement.
