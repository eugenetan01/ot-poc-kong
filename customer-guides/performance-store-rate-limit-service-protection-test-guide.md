# Performance Store Rate Limit And Service Protection Customer Test Guide

This guide is for customer validation of the performance rate-limit and service-protection requirement. Kong Gateway, Konnect configuration, OAuth client, Consumers, Redis, routes, plugins, upstream service, and infrastructure are assumed to already be set up.

The customer only needs to run the commands below and compare the result with the expected outcome.

## Test Endpoint

All public route examples use the load balancer hostname:

```text
https://apidev-kong.ot.id
```

## 1. Google SSO Enforcement For Store API

Requirement: anonymous store API traffic must be redirected to Google SSO before it reaches the backend.

Route:

```text
/performance/store-oauth-rate-limit
```

decK config: `kong/performance-service-protection.yaml` -> route `performance-store-oauth-rate-limit-route`, plugin instance `performance-store-oauth-google-auth-code`. Full mapping: `deck/performance-store-rate-limit-service-protection-scene-map.md`.

### Test 1.1: Unauthenticated Request Redirects To Google

Run:

```bash
curl -i "https://apidev-kong.ot.id/performance/store-oauth-rate-limit"
```

Expected result:

```text
HTTP/2 302
location: https://accounts.google.com/o/oauth2/v2/auth?...
```

Pass criteria:

```text
Kong redirects anonymous traffic to Google SSO.
```

### Test 1.2: Authenticated Browser User Reaches Backend

Run:

```bash
open "https://apidev-kong.ot.id/performance/store-oauth-rate-limit"
```

Expected result:

```text
Google login completes.
Kong maps the Google email claim to a Kong Consumer.
Kong forwards the request to WOLU Menus.
The backend returns HTTP 200.
```

Pass criteria:

```text
The Store API is reachable only after successful Google login.
```

## 2. Per-Store Consumer Rate Limit

Requirement: each authenticated store or user must receive an independent request quota so one store cannot consume all API capacity.

Bearer route:

```text
/performance/store-oauth-rate-limit-bearer/
```

Per-Consumer limit:

```text
30 requests per 60 seconds
```

decK config: `kong/performance-service-protection.yaml` -> route `performance-store-oauth-rate-limit-bearer-route`, plugin instances `performance-store-oauth-google-bearer` and `performance-store-oauth-bearer-per-consumer-rate-limit`. Full mapping: `deck/performance-store-rate-limit-service-protection-scene-map.md`.

### Test 2.1: One Consumer Is Limited After 30 Requests

Use a valid Google ID token whose `email` claim matches an onboarded Kong Consumer.

Run:

```bash
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32; do
  curl -s -o /dev/null -w "request $i -> %{http_code}\n" \
    "https://apidev-kong.ot.id/performance/store-oauth-rate-limit-bearer/" \
    -H "Authorization: Bearer <store-google-id-token>"
done
```

Expected result:

```text
Requests within the first 30 return 200.
Requests after the 30 request quota return 429.
```

Pass criteria:

```text
Kong enforces the per-Consumer store quota and returns HTTP 429 after the Consumer exceeds 30 requests in the 60 second window.
```

Note:

```text
Replace <store-google-id-token> with a valid Google ID token for a Consumer already configured in Kong.
If this test was recently run, wait for the 60 second window to reset before rerunning.
```

## 3. Service Protection Shared API Ceiling

Requirement: the backend API must have a shared safety ceiling so aggregate traffic cannot overload the service even when individual stores remain within their own quota.

Bearer route:

```text
/performance/store-oauth-rate-limit-bearer/
```

Policy behavior:

```text
Per-Consumer quota: 30 requests per 60 seconds
Service Protection ceiling: 50 requests per 60 seconds total
```

decK config: `kong/performance-service-protection.yaml` -> service `performance-store-oauth-api-service`, service plugin instance `performance-store-oauth-api-service-protection`, and bearer route plugin instance `performance-store-oauth-bearer-per-consumer-rate-limit`. Full mapping: `deck/performance-store-rate-limit-service-protection-scene-map.md`.

### Test 3.1: Two Consumers Stay Within Quota But Service Cap Rejects Excess

Use two valid Google ID tokens whose `email` claims match two onboarded Kong Consumers.

Run:

```bash
tmp_dir="$(mktemp -d)"

seq 30 | xargs -P 30 -I{} sh -c '
  curl -s -o /dev/null -w "%{http_code}\n" \
    "https://apidev-kong.ot.id/performance/store-oauth-rate-limit-bearer/" \
    -H "Authorization: Bearer <store-1-google-id-token>"
' > "$tmp_dir/store-1.txt" &

seq 30 | xargs -P 30 -I{} sh -c '
  curl -s -o /dev/null -w "%{http_code}\n" \
    "https://apidev-kong.ot.id/performance/store-oauth-rate-limit-bearer/" \
    -H "Authorization: Bearer <store-2-google-id-token>"
' > "$tmp_dir/store-2.txt" &

wait

echo "STORE-1:"
sort "$tmp_dir/store-1.txt" | uniq -c
echo "STORE-2:"
sort "$tmp_dir/store-2.txt" | uniq -c
echo "AGGREGATE:"
cat "$tmp_dir/store-1.txt" "$tmp_dir/store-2.txt" | sort | uniq -c
```

Expected result:

```text
AGGREGATE:
  50 200
  10 429
```

The exact Consumer that receives the `429` responses can vary because both Consumers send traffic concurrently.

Pass criteria:

```text
Each Consumer sends only 30 requests, which is within the per-store quota, while Kong rejects the aggregate excess above the 50 request service ceiling.
```

Note:

```text
Replace <store-1-google-id-token> and <store-2-google-id-token> with valid Google ID tokens for two different Consumers already configured in Kong.
If the result is slightly above or below 50/10, the test likely crossed a fixed-minute boundary or another request used the same service during that minute. Wait for the next minute and rerun.
```
