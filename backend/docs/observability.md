# OBS-01 — Privacy and operations

Analytics is opt-in per `(user_id, chef_id)`. The consumer API resolves the
tenant from `X-Tenant-Slug`; it never accepts a tenant ID or dashboard scope
from the client. When consent is off, events are dropped.

`analytics_events` accepts only the allowlisted funnel names and coarse
outcomes. It has no JSON properties column by design: do not add transcripts,
email addresses, ingredient/allergen/health data, recipe identifiers, product
prices, or store receipts. `analytics_tenant_daily_funnel` is the dashboard
read model and always groups by `chef_id`.

Operational checks:

- `GET /health` is a liveness probe and is safe for public load balancers.
- `GET /health/ready` is a deployment-only readiness check; it returns missing
  *variable names* only, never values.
- Unexpected errors are logged with route and exception class, never request
  body or exception text. Configure the deployment log/error sink with the
  same redaction policy.
- `ai_cost_daily` is the cost-dashboard contract: aggregate counts/tokens by
  tenant/day/model only. The scheduled cost exporter must upsert it from the
  provider's aggregate usage API and must not persist prompts or completions.

Account deletion cascades analytics consent and events through their `users`
foreign keys. Retention/deletion requests therefore need no separate event
purge worker. Apply `2026_07_16_observability.sql` before enabling analytics.
