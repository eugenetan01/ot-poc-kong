# Usability Route And Host Routing Customer Test Guide

This guide is for customer validation of the route-based and host-based routing usability requirement. Kong Gateway, Konnect configuration, routes, plugins, upstream services, and infrastructure are assumed to already be set up.

The customer only needs to run the curl commands below and compare the result with the expected outcome.

## Test Endpoint

All curl examples use the public load balancer hostname:

```text
https://apidev-kong.ot.id
```

## 1. Path-Based Routing

Requirement: Kong must route traffic to different backend services based on the request path.

Routes:

```text
/transactions/
/api/v1/products/
/api/v1/stores/
```

decK config: `kong/usability-route-host-routing.yaml` -> routes `usability-routing-transactions-path-route`, `usability-routing-products-path-route`, and `usability-routing-stores-path-route`. Full mapping: `deck/usability-route-host-routing-scene-map.md`.

### Test 1.1: Transactions Path Routes To Transaction Service

Run:

```bash
curl -i "https://apidev-kong.ot.id/transactions/?page=1&size=1"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
The request is routed to the WOLU Transaction Service.
```

### Test 1.2: Products Path Routes To Master Products

Run:

```bash
curl -i "https://apidev-kong.ot.id/api/v1/products/?status=active&page=1&size=1"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
The request is routed to the WOLU Master Products endpoint.
```

### Test 1.3: Stores Path Routes To Master Stores

Run:

```bash
curl -i "https://apidev-kong.ot.id/api/v1/stores/?status=all&page=1&size=1"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
The request is routed to the WOLU Master Stores endpoint.
```

## 2. Host-Based Routing

Requirement: Kong must route traffic to different backend services based on the request hostname.

Host-based routes:

```text
transactions.ot.local + /transactions/
products.ot.local     + /api/v1/products/
stores.ot.local       + /api/v1/stores/
```

decK config: `kong/usability-route-host-routing.yaml` -> routes `usability-routing-transactions-host-route`, `usability-routing-products-host-route`, and `usability-routing-stores-host-route`. Full mapping: `deck/usability-route-host-routing-scene-map.md`.

### Test 2.1: Transactions Host Routes To Transaction Service

Run:

```bash
curl -i "https://apidev-kong.ot.id/transactions/?page=1&size=1" \
  -H "Host: transactions.ot.local"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
The Host header selects the transactions route and reaches the WOLU Transaction Service.
```

### Test 2.2: Products Host Routes To Master Products

Run:

```bash
curl -i "https://apidev-kong.ot.id/api/v1/products/?status=active&page=1&size=1" \
  -H "Host: products.ot.local"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
The Host header selects the products route and reaches the WOLU Master Products endpoint.
```

### Test 2.3: Stores Host Routes To Master Stores

Run:

```bash
curl -i "https://apidev-kong.ot.id/api/v1/stores/?status=all&page=1&size=1" \
  -H "Host: stores.ot.local"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
The Host header selects the stores route and reaches the WOLU Master Stores endpoint.
```

## 3. Independent Route Policies

Requirement: each route must be able to carry its own gateway policy.

Policy behavior:

```text
Transactions route limit: 10 requests per minute
Products route limit: 3 requests per minute
Stores route limit: 3 requests per minute
```

decK config: `kong/usability-route-host-routing.yaml` -> route-level `rate-limiting-advanced` plugin instances for each path and host route. Full mapping: `deck/usability-route-host-routing-scene-map.md`.

### Test 3.1: Products Route Hits Lower Rate Limit

Run:

```bash
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w "request $i -> %{http_code}\n" \
    "https://apidev-kong.ot.id/api/v1/products/?status=active&page=1&size=1"
done
```

Expected result:

```text
request 1 -> 200
request 2 -> 200
request 3 -> 200
request 4 -> 429
request 5 -> 429
```

Pass criteria:

```text
Kong applies the lower Products route policy and returns HTTP 429 after the route limit is exceeded.
```

Note:

```text
If the route was recently tested, the rate-limit counter may already be active. Wait 60 seconds and rerun the test.
```

### Test 3.2: Transactions Route Remains Below Higher Limit

Run:

```bash
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w "request $i -> %{http_code}\n" \
    "https://apidev-kong.ot.id/transactions/?page=1&size=1"
done
```

Expected result:

```text
request 1 -> 200
request 2 -> 200
request 3 -> 200
request 4 -> 200
request 5 -> 200
```

Pass criteria:

```text
The same request count remains below the higher Transactions route limit.
```
