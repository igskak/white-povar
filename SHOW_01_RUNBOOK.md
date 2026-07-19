# White Povar — SHOW-01 demo runbook

## Guardrails

- Use the prepared, separate free viewer, allowlisted buyer, and Studio admin
  identities. Their credentials are held outside git.
- Demo mode never represents a charged payment. The web UI must keep the
  "Кошти не списуються" disclosure visible before activation.
- Do not edit production tables manually during a demo. Reset through the
  product UI and the internal demo-entitlement tool only.

## Pre-run reset

1. Check that the buyer has no active demo entitlement.
2. If necessary, revoke demo entitlements with the internal-only operation:

   ```bash
   cd backend
   .venv/bin/python3 tools/demo_commerce.py revoke \
     --tenant ohorodnik-oleksandr --email <prepared-buyer-email>
   ```

3. In the free-viewer account, clear Saved, pantry, shopping, weekly menu and
   preferences through the UI when a clean first-run state is required.
4. Confirm the published BrandConfig matches the approved Studio version.

## Seven-to-ten minute flow

1. Show tenant branding on Home and a free recipe.
2. Show typed recommendation and voice/camera fallback disclosure.
3. Show the premium collection locked for the free viewer.
4. Sign in as the allowlisted buyer and open the demo paywall.
5. Point out the no-charge disclosure; activate demo access.
6. Reload once, then open a premium material.
7. Briefly show the Studio draft/preview path with the Studio admin.
8. Explain that Stripe Checkout is the next real-payment step and that
   tenant-scoped access is already server-authoritative.

## Post-run reset and fallback

- Revoke the buyer entitlement and reload the premium collection: it must be
  locked again.
- Restore the approved Studio BrandConfig version if a demo draft was
  published.
- Use the prepared screenshots in the QA journal if Render is waking or the
  connection is unstable; do not claim a live charge.

## Feedback prompts

- What makes a branded cooking app valuable for your audience?
- Which paid content formats would you create first?
- Would you prefer subscription, one-off collections, or both?
- Who would maintain your catalogue and Studio workflow?
- Which branding and analytics signals matter before a pilot?
