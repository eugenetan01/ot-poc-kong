# Performance Store Rate Limit And Service Protection Scene To decK Config Map

This file maps each customer test scene in `customer-guides/performance-store-rate-limit-service-protection-test-guide.md` to the Kong decK configuration that implements it.

All performance store rate-limit and service-protection scenes are configured in:

```text
kong/performance-service-protection.yaml
```

## 1. Google SSO Enforcement For Store API

Customer guide section:

```text
1. Google SSO Enforcement For Store API
```

decK config:

```text
File: kong/performance-service-protection.yaml
Service: performance-store-oauth-api-service
Route: performance-store-oauth-rate-limit-route
Route paths:
- /performance/store-oauth-rate-limit
- /performance/store-oauth-rate-limit/
Method: GET
Upstream host: wolu-master-service-175096896148.asia-southeast2.run.app
Upstream path: /api/v1/menus/
Plugin: openid-connect
Plugin instance: performance-store-oauth-google-auth-code
Auth methods: authorization_code, session
Consumer mapping: Google email claim -> Kong Consumer username
Tags: performance, orangtua, service-protection, store-oauth-rate-limit
```

## 2. Per-Store Consumer Rate Limit

Customer guide section:

```text
2. Per-Store Consumer Rate Limit
```

Bearer route decK config:

```text
File: kong/performance-service-protection.yaml
Service: performance-store-oauth-api-service
Route: performance-store-oauth-rate-limit-bearer-route
Route path: /performance/store-oauth-rate-limit-bearer/
Method: GET
Upstream host: wolu-master-service-175096896148.asia-southeast2.run.app
Upstream path: /api/v1/menus/
Plugin: openid-connect
Plugin instance: performance-store-oauth-google-bearer
Auth methods: bearer
Consumer mapping: Google email claim -> Kong Consumer username
```

Per-Consumer rate-limit decK config:

```text
File: kong/performance-service-protection.yaml
Plugin: rate-limiting-advanced
Plugin instance: performance-store-oauth-bearer-per-consumer-rate-limit
Identifier: consumer
Strategy: redis
Redis host: kong-redis
Redis port: 6379
Limit: 30 requests per 60 seconds
Window type: fixed
Namespace: performance-store-oauth-bearer-per-consumer-v1
Error code: 429
Error message: Store quota exceeded
```

Browser route also has the same per-Consumer policy:

```text
Plugin: rate-limiting-advanced
Plugin instance: performance-store-oauth-per-consumer-rate-limit
Identifier: consumer
Strategy: redis
Limit: 30 requests per 60 seconds
Namespace: performance-store-oauth-per-consumer-v1
```

## 3. Service Protection Shared API Ceiling

Customer guide section:

```text
3. Service Protection Shared API Ceiling
```

Service-level decK config:

```text
File: kong/performance-service-protection.yaml
Service: performance-store-oauth-api-service
Plugin: service-protection
Plugin instance: performance-store-oauth-api-service-protection
Strategy: redis
Redis host: kong-redis
Redis port: 6379
Limit: 50 requests per 60 seconds
Namespace: performance-store-oauth-api-service-protection-v1
disable_penalty: true
Tags: performance, orangtua, service-protection, store-oauth-rate-limit
```

Combined policy model:

```text
Per-store fairness: rate-limiting-advanced, 30 requests per Consumer per 60 seconds
Backend safety ceiling: service-protection, 50 requests total per service per 60 seconds
Counter store: Redis
Expected two-Consumer burst: 50 successful responses and 10 rate-limited responses
```

Supporting helper:

```text
Script: scripts/demo-performance-service-protection.sh
Default public base URL: https://apidev-kong.ot.id
Bearer route used by helper: /performance/store-oauth-rate-limit-bearer/
```
