# Performance Checkout 1,000 RPS Scene To decK Config Map

This file maps each customer test scene in `customer-guides/performance-checkout-1000-load-test-guide.md` to the Kong decK configuration and load-test files that implement it.

## 1. Checkout Route Smoke Test

Customer guide section:

```text
1. Checkout Route Smoke Test
```

decK config:

```text
File: kong/performance-checkout-1000.yaml
Service: performance-checkout-1000-service
Route: performance-checkout-1000-route
Route path: /performance/transactions-checkout/
Method: GET
Upstream host: wolu-trx-service-175096896148.asia-southeast2.run.app
Upstream path: /transactions/
Tags: performance, checkout-1000
```

## 2. Direct Upstream Baseline Load Test

Customer guide section:

```text
2. Direct Upstream Baseline Load Test
```

Load-test config:

```text
File: scripts/performance-checkout-1000.js
Executor: constant-arrival-rate
Default rate: 1000 requests per second
Default duration: 60s
Default pre-allocated VUs: 200
Startup/rerun pre-allocated VUs: 300
Default max VUs: 1000
Startup/rerun max VUs: 1200
Threshold: http_req_failed rate < 1%
Threshold: http_req_duration p95 < P95_THRESHOLD
```

Baseline target:

```text
https://wolu-trx-service-175096896148.asia-southeast2.run.app/transactions/?page=1&size=1
```

Helper scripts:

```text
Startup helper: scripts/performance-checkout-1000-startup.sh
Rerun helper: scripts/performance-checkout-1000-rerun.sh
Latest startup log: dump/performance-checkout-1000/latest.log
Latest rerun log: dump/performance-checkout-1000/latest-rerun.log
```

## 3. Kong-Proxied Checkout Load Test

Customer guide section:

```text
3. Kong-Proxied Checkout Load Test
```

decK config:

```text
File: kong/performance-checkout-1000.yaml
Service: performance-checkout-1000-service
Route: performance-checkout-1000-route
Route path: /performance/transactions-checkout/
Method: GET
Upstream host: wolu-trx-service-175096896148.asia-southeast2.run.app
Upstream path: /transactions/
Tags: performance, checkout-1000
```

Kong-proxied target:

```text
https://apidev-kong.ot.id/performance/transactions-checkout/?page=1&size=1
```

Load-test config:

```text
File: scripts/performance-checkout-1000.js
TARGET_URL: https://apidev-kong.ot.id/performance/transactions-checkout/?page=1&size=1
RATE: 1000
DURATION: 60s
PRE_ALLOCATED_VUS: 300
MAX_VUS: 1200
```

## 4. Added Latency Check

Customer guide section:

```text
4. Added Latency Check
```

Calculation:

```text
Kong added p95 latency = Kong-proxied p95 - direct upstream baseline p95
```

Success criteria:

```text
Failed requests: < 1%
Added p95 latency: < 50 ms
```
