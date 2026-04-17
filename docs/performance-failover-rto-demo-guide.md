# Performance Failover And Zero-Downtime Demo Guide

This scene demonstrates:

```text
Failover & Zero-Downtime (RPO/RTO)
```

The demo focuses on upstream application failover with Kong load balancing, active health checks, and passive health checks/circuit breaking.

All Kong entities in this scene are tagged:

```text
performance
failover-rto
```

## Requirement Mapping

| Requirement Column | Demo Implementation |
| --- | --- |
| POS handles real-time transactions | `/performance/failover` represents the transaction path |
| Upstream Cloud Run failure | Stop the primary backend container on the VM |
| Auto-recovery without manual intervention | Restart primary and active health checks return it to rotation |
| RPO/RTO near-zero | No data is stored in Kong; routing recovers within the health-check window |
| Active health checks | Kong probes `/health` every 2 seconds |
| Passive health checks / circuit breaker | Kong marks a target unhealthy after request failures |
| Multiple Cloud Run targets | Kong Upstream has primary and secondary targets |
| Load balancing | Upstream uses round-robin across healthy targets |

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
  | curl demo traffic locally
  v
Kong :8000 -> performance-failover-upstream
                |-> primary backend
                |-> secondary backend
```

## Entities

Kong route:

```text
GET /performance/failover
```

Kong service:

```text
performance-failover-service -> performance-failover-upstream
```

The service has retries enabled:

```text
retries: 2
```

This matters during live failure. If one in-flight request lands on the failed primary before health checks have removed it from rotation, Kong retries another target and can still return a successful response from secondary.

Kong upstream:

```text
performance-failover-upstream
```

Targets:

```text
primary backend container
secondary backend container
```

## Startup

Run from the project root:

```bash
./scripts/performance-failover-startup.sh
```

The startup script:

```text
1. SSHes through the jumpbox to the VM
2. Starts primary and secondary nginx backend containers
3. Discovers their container IPs
4. Generates and syncs the Kong Upstream, Service, Route, and Targets
5. Warms up /performance/failover
```

## Demo

Run:

```bash
./scripts/performance-failover-demo.sh
```

The demo script:

```text
1. Shows normal load balancing across primary and secondary
2. Stops the primary backend
3. Waits for health checks
4. Shows traffic continues on secondary
5. Starts the primary backend
6. Waits for health checks
7. Shows primary returns to rotation
```

Useful overrides:

```bash
SAMPLE_COUNT=20 FAILOVER_WAIT=8 RECOVERY_WAIT=8 ./scripts/performance-failover-demo.sh
```

## Manual Step-By-Step Demo

Use this flow when you want to present the scene curl by curl.

Check containers:

```bash
./scripts/performance-failover-step.sh status
```

Send one request:

```bash
./scripts/performance-failover-step.sh curl-once
```

Show normal load balancing:

```bash
COUNT=12 ./scripts/performance-failover-step.sh curl-loop
```

Expected:

```text
Responses alternate between primary and secondary, all HTTP_STATUS:200.
```

Stop the primary backend:

```bash
./scripts/performance-failover-step.sh stop-primary
```

Wait for health checks:

```bash
WAIT=6 ./scripts/performance-failover-step.sh wait
```

Show failover:

```bash
COUNT=12 ./scripts/performance-failover-step.sh curl-loop
```

Expected:

```text
All responses come from secondary, all HTTP_STATUS:200.
```

Recover the primary backend:

```bash
./scripts/performance-failover-step.sh start-primary
```

Wait for active health checks:

```bash
WAIT=6 ./scripts/performance-failover-step.sh wait
```

Show recovery:

```bash
COUNT=12 ./scripts/performance-failover-step.sh curl-loop
```

Expected:

```text
Primary returns to rotation with secondary, all HTTP_STATUS:200.
```

## Live Auto-Failover Watch

Use this flow when you want to see failover happen live.

Terminal 1, start a continuous request loop:

```bash
COUNT=0 SLEEP=0.5 ./scripts/performance-failover-step.sh watch
```

Expected while both targets are healthy:

```text
primary
secondary
primary
secondary
```

Terminal 2, stop the primary backend:

```bash
./scripts/performance-failover-step.sh stop-primary
```

Watch Terminal 1. After health-check convergence, expected output:

```text
secondary
secondary
secondary
secondary
```

With service retries enabled, the transition should stay client-visible `HTTP_STATUS:200`. Without retries, one unlucky in-flight request can briefly return `504` before Kong marks the failed target unhealthy.

Terminal 2, start primary again:

```bash
./scripts/performance-failover-step.sh start-primary
```

Watch Terminal 1. After active health checks mark primary healthy again, expected output:

```text
primary
secondary
primary
secondary
```

Stop the watcher with:

```text
Ctrl-C
```

For a bounded test instead of an infinite watch:

```bash
COUNT=20 SLEEP=0.5 ./scripts/performance-failover-step.sh watch
```

## Teardown

Run:

```bash
./scripts/performance-failover-teardown.sh
```

The teardown script:

```text
1. Removes performance+failover-rto tagged entities from Konnect
2. Removes primary and secondary backend containers from the VM
3. Removes the temporary Docker network
4. Removes temporary VM files
```

## How To Read The Results

Use:

```bash
rg -n "Normal load balancing|After primary failure|After recovery|HTTP_STATUS|backend" dump/performance-failover-rto/latest-demo.log
```

Expected before failure:

```text
primary and secondary both return HTTP_STATUS:200
```

Expected during failure:

```text
secondary returns HTTP_STATUS:200
no client-facing 5xx responses after health-check convergence
```

Expected after recovery:

```text
primary and secondary return HTTP_STATUS:200 again
```

## Captured Test Result

Run:

```bash
./scripts/performance-failover-startup.sh
./scripts/performance-failover-demo.sh
```

Result log:

```text
dump/performance-failover-rto/latest-demo.log
```

Observed result:

```text
Normal load balancing:
12/12 requests returned HTTP_STATUS:200
Responses alternated between primary and secondary

After primary failure:
12/12 requests returned HTTP_STATUS:200
All responses came from secondary

After primary recovery:
12/12 requests returned HTTP_STATUS:200
Primary returned to rotation with secondary
```

Demo timings:

```text
FAILOVER_WAIT=6 seconds
RECOVERY_WAIT=6 seconds
```

This demonstrates that Kong removed the unhealthy target and restored it automatically within the configured health-check window.

## RPO/RTO Positioning

Use this wording:

```text
This POC demonstrates upstream failure handling. Kong detects an unhealthy target, removes it from load balancing, and returns it automatically after recovery. RTO is governed by the configured active/passive health-check window. RPO for gateway routing is effectively zero because Kong does not store transaction data and data planes retain their last known config locally.
```

For data plane crash HA:

```text
True zero-downtime data plane crash handling requires at least two Kong data planes behind a load balancer. This POC VM has one Kong data plane, so we demonstrate upstream failover here and document the production DP HA pattern.
```
