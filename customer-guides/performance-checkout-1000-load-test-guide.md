# Performance Checkout 1,000 RPS Customer Test Guide

This guide is for customer validation of the checkout load-testing performance requirement. Kong Gateway, Konnect configuration, route, upstream service, load-test machine, and infrastructure are assumed to already be set up.

The customer only needs to run the commands below and compare the result with the expected outcome.

## Test Endpoint

The Kong route uses the public load balancer hostname:

```text
https://apidev-kong.ot.id
```

## 1. Checkout Route Smoke Test

Requirement: the checkout test route must proxy to the WOLU Transaction API before load testing starts.

Route:

```text
/performance/transactions-checkout/
```

decK config: `kong/performance-checkout-1000.yaml` -> route `performance-checkout-1000-route`, service `performance-checkout-1000-service`. k6 script: `scripts/performance-checkout-1000.js`. Full mapping: `deck/performance-checkout-1000-scene-map.md`.

### Test 1.1: Kong Checkout Route Returns 200

Run:

```bash
curl -i "https://apidev-kong.ot.id/performance/transactions-checkout/?page=1&size=1"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
Kong forwards the request to the WOLU Transaction API.
```

## 2. Direct Upstream Baseline Load Test

Requirement: measure the direct WOLU Transaction API baseline before comparing Kong-proxied latency.

Target:

```text
https://wolu-trx-service-175096896148.asia-southeast2.run.app/transactions/?page=1&size=1
```

decK config: no Kong config is used for the baseline. The baseline uses the same k6 script, `scripts/performance-checkout-1000.js`, pointed directly at the upstream. Full mapping: `deck/performance-checkout-1000-scene-map.md`.

### Test 2.1: Run Baseline At 1,000 RPS

Run from the repository root:

```bash
docker run --rm \
  -v "$PWD/scripts:/scripts" \
  -e TARGET_URL="https://wolu-trx-service-175096896148.asia-southeast2.run.app/transactions/?page=1&size=1" \
  -e RATE=1000 \
  -e DURATION=60s \
  -e PRE_ALLOCATED_VUS=300 \
  -e MAX_VUS=1200 \
  grafana/k6 run /scripts/performance-checkout-1000.js
```

Expected result:

```text
http_reqs shows approximately 60,000 total requests for a 60 second run.
http_req_failed is below 1%.
http_req_duration p(95) is captured as the direct upstream baseline p95.
checks show status is 200.
```

Pass criteria:

```text
The direct WOLU baseline completes successfully and records the upstream p95 latency used for comparison.
```

## 3. Kong-Proxied Checkout Load Test

Requirement: Kong must handle 1,000 RPS checkout-style traffic with less than 50 ms added p95 latency compared with the direct upstream baseline.

Route:

```text
/performance/transactions-checkout/
```

decK config: `kong/performance-checkout-1000.yaml` -> route `performance-checkout-1000-route`, service `performance-checkout-1000-service`. k6 script: `scripts/performance-checkout-1000.js`. Full mapping: `deck/performance-checkout-1000-scene-map.md`.

### Test 3.1: Run Kong-Proxied Test At 1,000 RPS

Run from the repository root:

```bash
docker run --rm \
  -v "$PWD/scripts:/scripts" \
  -e TARGET_URL="https://apidev-kong.ot.id/performance/transactions-checkout/?page=1&size=1" \
  -e RATE=1000 \
  -e DURATION=60s \
  -e PRE_ALLOCATED_VUS=300 \
  -e MAX_VUS=1200 \
  grafana/k6 run /scripts/performance-checkout-1000.js
```

Expected result:

```text
http_reqs shows approximately 60,000 total requests for a 60 second run.
http_req_failed is below 1%.
http_req_duration p(95) is captured as the Kong-proxied p95.
checks show status is 200.
```

Pass criteria:

```text
Kong successfully proxies the 1,000 RPS test with less than 1% failed requests.
```

## 4. Added Latency Check

Requirement: Kong must add less than 50 ms p95 latency.

Use the p95 values from Test 2.1 and Test 3.1:

```text
Kong added p95 latency = Kong-proxied p95 - direct upstream baseline p95
```

Pass criteria:

```text
Kong added p95 latency is less than 50 ms.
```

Example result format:

```text
Direct upstream p95: <baseline-p95-ms>
Kong-proxied p95:   <kong-p95-ms>
Added p95 latency:  <kong-p95-ms - baseline-p95-ms>
Result: PASS if added p95 latency < 50 ms
```
