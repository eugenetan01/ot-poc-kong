# Performance OAuth Store Rate Limiting Demo Guide

This scene demonstrates the Performance tab requirement:

```text
Enable the Rate Limiting feature. Limit each store so one store cannot consume all available API capacity.
```

The scene uses two Kong controls together:

```text
Rate Limiting Advanced: 30 requests per minute per authenticated store Consumer, counted in Redis
Service Protection: 50 requests per minute total on the Gateway Service, counted in Redis
```

## Entity Tags

All entities in this scene are tagged:

```text
performance
orangtua
service-protection
store-oauth-rate-limit
```

## Kong Entities

Gateway Service:

```text
performance-store-oauth-api-service
-> https://wolu-master-service-175096896148.asia-southeast2.run.app/api/v1/menus/
```

Route:

```text
GET https://apidev-kong.ot.id/performance/store-oauth-rate-limit
```

Bearer load-test route:

```text
GET https://apidev-kong.ot.id/performance/store-oauth-rate-limit-bearer/
```

OAuth identity mapping:

```text
Google ID token email claim -> Kong Consumer username
```

Current Consumers used in the demo:

```text
ahmad.ridwan@ot.id
ginanjar.sumantri@ot.id
```

Ahmad and Ginanjar are existing Kong Consumers already present in the shared control plane from the security OIDC scene. This scene reuses them through the same Google `email` claim mapping.

For customer testing, add each store or user email as a Kong Consumer username:

```text
store-001@customer-domain.com
store-002@customer-domain.com
store-003@customer-domain.com
```

## Policy Model

OpenID Connect:

```yaml
consumer_claim:
  - email
consumer_by:
  - username
```

The browser route uses:

```yaml
auth_methods:
  - authorization_code
  - session
login_action: redirect
```

The burst-test route uses:

```yaml
auth_methods:
  - bearer
```

Rate Limiting Advanced:

```yaml
identifier: consumer
consumer_claim:
  - email
consumer_by:
  - username
limit:
  - 30
window_size:
  - 60
window_type: fixed
strategy: redis
sync_rate: 0
redis:
  host: kong-redis
  port: 6379
```

That means the store/user identity is resolved like this:

```text
Google ID token `email` claim -> Kong Consumer username -> independent 30 requests/minute Redis bucket
```

Example:

```text
ahmad.ridwan@ot.id receives its own 30/min bucket.
ginanjar.sumantri@ot.id receives a separate 30/min bucket.
```

Service Protection:

```yaml
limit:
  - 50
window_size:
  - 60
strategy: redis
sync_rate: 0
redis:
  host: kong-redis
  port: 6379
```

Why this proves the requirement:

```text
Each Google-authenticated store maps to a Kong Consumer.
Each Consumer receives an independent 30 requests/minute bucket backed by Redis.
In the demo, Ahmad and Ginanjar each send 30 requests, so neither user exceeds their own Consumer quota.
The service has a separate 50 requests/minute Redis-backed safety ceiling to protect the backend.
When both users send 30 requests at the same time, the service receives 60 requests total and Service Protection rejects the excess.
```

## Google Setup

The Google OAuth client in `client_secret_16948355927-rehp0qlv1vgh33uc9crt3rulob1f9fv2.apps.googleusercontent.com.json` must match the shared demo client shown in Google Cloud:

```text
Client ID: 16948355927-rehp0q...
Authorized redirect URI: https://apidev-kong.ot.id/performance/store-oauth-rate-limit
```

This is intentionally separate from the Security OIDC scene:

```text
/security/oidc -> google-sso.json
/performance/store-oauth-rate-limit -> client_secret_16948355927-rehp0qlv1vgh33uc9crt3rulob1f9fv2.apps.googleusercontent.com.json
```

The OAuth consent screen must include:

```text
openid
email
profile
```

## Setup

Sync the scene:

```bash
./scripts/sync-performance-service-protection.sh
```

For the two-Consumer burst test, install `hey` on the machine running the demo helper:

```bash
brew install hey
```

To rotate the demo counters and sync:

```bash
./scripts/reset-performance-service-protection.sh
```

Redis for this scene runs on the VM as Docker container `kong-redis` and is reachable by Kong at:

```text
kong-redis:6379
```

## Scene 1: Unauthenticated Traffic Goes To Google SSO

Run:

```bash
curl -i https://apidev-kong.ot.id/performance/store-oauth-rate-limit
```

Expected:

```text
HTTP/2 302
location: https://accounts.google.com/o/oauth2/v2/auth?...
```

Presenter line:

```text
Kong does not allow anonymous traffic to the Store API. The user must authenticate through Google SSO first.
```

## Scene 2: Authenticated Store Reaches The Backend

Run:

```bash
open https://apidev-kong.ot.id/performance/store-oauth-rate-limit
```

Expected:

```text
Google login completes.
Kong maps the Google email claim to a Kong Consumer.
Kong forwards the clean request to WOLU Menus.
WOLU returns HTTP 200.
```

## Scene 3: Two Consumers Stay Within Quota But The API Cap Kicks In

Use two valid Google ID tokens whose `email` claims match the onboarded Kong Consumers. The token audience must match the OAuth client configured on this route.

First rotate the demo namespaces so the counters are clean:

```bash
./scripts/reset-performance-service-protection.sh
```

Wait a few seconds for the Konnect data plane to receive the update.

Run:

```bash
STORE_1_TOKEN='<ahmad-id-token>' \
STORE_2_TOKEN='<ginanjar-id-token>' \
CONSUMER_REQUESTS=30 \
./scripts/demo-performance-service-protection.sh
```

The helper uses the bearer-only route for this test:

```text
https://apidev-kong.ot.id/performance/store-oauth-rate-limit-bearer/
```

The output should include:

```text
Auth mode: bearer token
Burst route: https://apidev-kong.ot.id/performance/store-oauth-rate-limit-bearer/
Burst window: fixed 1 minute
Waiting for the next fresh fixed-minute window...
Burst engine: hey
```

Expected:

```text
STORE-1:
    30 200
STORE-2:
    20 200
    10 429
AGGREGATE:
    50 200
    10 429
```

The exact Consumer that receives the `429` responses can vary because both Consumers race at the same time. The important result is that each Consumer sends only 30 requests, which is within their own 30/min Consumer quota, while the aggregate total exceeds the 50/min service cap.

If the output shows `307`, the test is hitting the browser route or a non-canonical upstream path instead of the bearer route.
If the output is slightly above or below `50/10`, the burst likely crossed a fixed-minute boundary or another request used the same service during that minute. Rerun `./scripts/reset-performance-service-protection.sh`, wait a few seconds for sync, and rerun the helper. The helper waits for the next fresh minute before firing the burst.

Presenter line:

```text
Each Consumer is still within its own fair-use quota. Kong rejects the excess aggregate traffic because the protected API service has reached its shared safety ceiling.
```

The bearer route is intentionally separate from the browser route so the load test does not count browser login redirects as API responses.

## Scene 4: Service Protection Ceiling

Service Protection is configured separately from the per-store limit:

```text
50 requests per minute total on the Gateway Service
```

Presenter line:

```text
Rate Limiting Advanced protects fairness per store. Service Protection protects the backend service as a whole. Redis makes the counters shared across Kong data planes instead of per-node.
```

The bearer route keeps its trailing slash intentionally. The WOLU backend canonicalizes list endpoints with a trailing slash, and using it directly keeps the bearer load-test output free of upstream `307` redirects.
