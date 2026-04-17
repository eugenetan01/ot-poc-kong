# Performance Checkout 1,000 RPS Demo Guide

This scene demonstrates:

```text
Send 1,000 requests per second simulating checkout traffic
```

The test runs the load generator on the VM behind the jumpbox. The jumpbox is only used for SSH access, not for carrying test traffic.

## Requirement Mapping

| Requirement | Demo Implementation |
| --- | --- |
| Simulate peak checkout load across stores | k6 constant-arrival-rate test at 1,000 RPS |
| Target less than 50ms added latency | Compare backend baseline latency with Kong proxied latency |
| Use one of the real Swagger APIs | WOLU Transaction `GET /transactions/` endpoint |
| Run load test with k6 or Locust | k6 runs via Docker on the VM |
| Tune worker processes to CPU count | Existing Kong 3.13 data plane is used; CPU is observed with Docker stats |

## Entities

All Kong entities in this scene are tagged:

```text
performance
checkout-1000
```

Kong route:

```text
GET /performance/transactions-checkout/?page=1&size=1
```

Functional WOLU route shape used for the story:

```text
GET /transactions/?page=1&size=1
```

Kong service:

```text
performance-checkout-1000-service -> https://wolu-trx-service-175096896148.asia-southeast2.run.app/transactions/
```

The route keeps the RFP demo path stable while Kong forwards to the Transaction service endpoint from the Swagger documentation.

## Architecture

```text
Laptop
  |
  | SSH only
  v
Jumpbox
  |
  | SSH only
  v
VM
  |
  | k6 generates 1,000 RPS locally
  v
Kong :8000 -> WOLU Transaction Cloud Run API
```

## Startup

Run from the project root:

```bash
./scripts/performance-checkout-1000-startup.sh
```

Run startup once before the demo. It syncs the Kong route and then runs the baseline and Kong-proxied tests.

Useful overrides:

```bash
RATE=1000 DURATION=60s ./scripts/performance-checkout-1000-startup.sh
RATE=500 DURATION=30s ./scripts/performance-checkout-1000-startup.sh
```

The startup script:

```text
1. Validates kong/performance-checkout-1000.yaml
2. Syncs only performance+checkout-1000 tagged entities to Konnect
3. SSHes through the jumpbox to the VM
4. Runs baseline k6 directly against the WOLU Transaction endpoint
5. Runs k6 through Kong at the same RPS
6. Saves the local output under dump/performance-checkout-1000/
```

## Quick Rerun

After startup has completed once, rerun the load test without recreating the backend or syncing Konnect:

```bash
./scripts/performance-checkout-1000-rerun.sh
```

Useful overrides:

```bash
RATE=1000 DURATION=60s ./scripts/performance-checkout-1000-rerun.sh
RATE=500 DURATION=30s ./scripts/performance-checkout-1000-rerun.sh
```

The rerun script:

```text
1. SSHes through the jumpbox to the VM
2. Verifies Kong is running
3. Verifies /performance/transactions-checkout returns 200
4. Runs baseline k6 directly against the WOLU Transaction endpoint
5. Runs k6 through Kong at the same RPS
6. Saves the local output under dump/performance-checkout-1000/
```

## Teardown

Run from the project root:

```bash
./scripts/performance-checkout-1000-teardown.sh
```

The teardown script:

```text
1. Removes performance+checkout-1000 tagged entities from Konnect
2. Removes any leftover temporary VM test files from previous runs
3. Removes any old local benchmark container/network if they still exist
```

## How To Read The Results

For the latest quick rerun, use this command:

```bash
rg -n "Baseline:|Kong:|http_reqs|http_req_failed|http_req_duration|checks_succeeded|Docker stats" dump/performance-checkout-1000/latest-rerun.log
```

Look for these k6 lines:

```text
http_reqs
http_req_failed
http_req_duration
checks
```

The key comparison is:

```text
Kong added latency = Kong p95 - backend p95
```

For the RFP discussion, present:

```text
Direct WOLU baseline p95
Kong proxied p95
Added p95 latency
Error rate
Kong Docker CPU and memory after test
```

## Captured Test Result

Run:

```text
RATE=1000 DURATION=60s PRE_ALLOCATED_VUS=300 MAX_VUS=1200 ./scripts/performance-checkout-1000-startup.sh
```

Result log:

```text
dump/performance-checkout-1000/latest.log
```

Measured on the VM behind the jumpbox. The latest configured scene now targets:

```text
https://wolu-trx-service-175096896148.asia-southeast2.run.app/transactions/?page=1&size=1
```

Older captured results from the previous isolated-backend benchmark should not be used for the WOLU Swagger endpoint demo. Run startup or rerun again to capture fresh WOLU numbers.

Success criteria:

```text
< 1% failed requests
< 50 ms added p95 latency at 1,000 RPS
```
