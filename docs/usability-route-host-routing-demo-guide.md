# Usability Route And Host Routing Demo Guide

This scene demonstrates:

```text
Support Route-based / Host-based Routing
```

All entities in this scene are tagged:

```text
usability
route-host-routing
```

## Requirement Mapping

| Kong Solution Column | Demo Implementation |
| --- | --- |
| Define Kong Route objects per path or host | Six routes: three path-based and three host-based |
| Link each Route to a Service | Transactions, Products, and Stores each have their own Gateway Service |
| Apply plugins at Route level | Each route has its own rate limit policy |
| Plugin priority: Route > Service > Global | The route-level limits are scoped directly to the route that receives traffic |

## Services

```text
usability-routing-transactions-service -> https://wolu-trx-service-175096896148.asia-southeast2.run.app
usability-routing-master-service       -> https://wolu-master-service-175096896148.asia-southeast2.run.app
```

The Gateway Services hold the upstream host only. The route objects own the documented API paths.

## Routes

Path-based routes:

```text
/transactions/      -> WOLU Transaction Service
/api/v1/products/   -> WOLU Master Products route on the Master service
/api/v1/stores/     -> WOLU Master Stores route on the Master service
```

Host-based routes:

```text
transactions.ot.local + /transactions/      -> WOLU Transaction Service
products.ot.local     + /api/v1/products/  -> WOLU Master Products route on the Master service
stores.ot.local       + /api/v1/stores/    -> WOLU Master Stores route on the Master service
```

## Scene 1: Path-Based Routing

Presenter line:

```text
The same Kong data plane routes by path to different backend services.
```

Commands:

```bash
curl -i "http://localhost:8000/transactions/?page=1&size=1"
curl -i "http://localhost:8000/api/v1/products/?status=active&page=1&size=1"
curl -i "http://localhost:8000/api/v1/stores/?status=all&page=1&size=1"
```

Expected:

```text
Transactions returns the WOLU Transaction Service response.
Products returns the WOLU Master Products response.
Stores returns the WOLU Master Stores response.
```

## Scene 2: Host-Based Routing

Presenter line:

```text
Kong can also route by hostname, which maps cleanly to functional API domains or Cloud Run service hostnames.
```

Commands:

```bash
curl -i "http://localhost:8000/transactions/?page=1&size=1" -H "Host: transactions.ot.local"
curl -i "http://localhost:8000/api/v1/products/?status=active&page=1&size=1" -H "Host: products.ot.local"
curl -i "http://localhost:8000/api/v1/stores/?status=all&page=1&size=1" -H "Host: stores.ot.local"
```

Expected:

```text
Each hostname reaches a different Gateway Service without changing the gateway listener.
```

## Scene 3: Independent Route Policies

Presenter line:

```text
Each route can carry its own policy. In this demo the transaction API has a higher route-level rate limit than Products and Stores.
```

Transactions has a higher limit:

```text
10 requests per minute
```

Products and Stores have lower limits:

```text
3 requests per minute
```

Trigger the lower Products limit:

```bash
for i in {1..5}; do
  curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:8000/api/v1/products/?status=active&page=1&size=1"
done
```

Expected:

```text
The fourth or fifth request returns 429.
```

Show transactions still has a higher threshold:

```bash
for i in {1..5}; do
  curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:8000/transactions/?page=1&size=1"
done
```

Expected:

```text
The same request count stays below the transaction route's limit.
```

## Apply Or Reapply

The latest backup taken before switching this scene to WOLU endpoints is stored in:

```text
dump/konnect-before-usability-route-host-wolu-20260415-153529.yaml
```

Apply only this scene:

```bash
deck gateway sync kong/usability-route-host-routing.yaml \
  --select-tag usability \
  --select-tag route-host-routing \
  --konnect-token "$KONNECT_PAT" \
  --konnect-control-plane-name "$TF_VAR_control_plane_name" \
  --konnect-addr "$KONNECT_REGION" \
  --yes
```
