# Usability Route And Host Routing Scene To decK Config Map

This file maps each customer test scene in `customer-guides/usability-route-host-routing-test-guide.md` to the Kong decK configuration that implements it.

All route and host routing scenes are configured in:

```text
kong/usability-route-host-routing.yaml
```

## 1. Path-Based Routing

Customer guide section:

```text
1. Path-Based Routing
```

Transactions path route decK config:

```text
File: kong/usability-route-host-routing.yaml
Service: usability-routing-transactions-service
Route: usability-routing-transactions-path-route
Path: /transactions/
Plugin: rate-limiting-advanced
Plugin instance: usability-routing-transactions-path-rate-limit
Limit: 10 requests per 60 seconds
```

Products path route decK config:

```text
File: kong/usability-route-host-routing.yaml
Service: usability-routing-master-service
Route: usability-routing-products-path-route
Path: /api/v1/products/
Plugin: rate-limiting-advanced
Plugin instance: usability-routing-products-path-rate-limit
Limit: 3 requests per 60 seconds
```

Stores path route decK config:

```text
File: kong/usability-route-host-routing.yaml
Service: usability-routing-master-service
Route: usability-routing-stores-path-route
Path: /api/v1/stores/
Plugin: rate-limiting-advanced
Plugin instance: usability-routing-stores-path-rate-limit
Limit: 3 requests per 60 seconds
```

## 2. Host-Based Routing

Customer guide section:

```text
2. Host-Based Routing
```

Transactions host route decK config:

```text
File: kong/usability-route-host-routing.yaml
Service: usability-routing-transactions-service
Route: usability-routing-transactions-host-route
Host: transactions.ot.local
Path: /transactions/
Plugin: rate-limiting-advanced
Plugin instance: usability-routing-transactions-host-rate-limit
Limit: 10 requests per 60 seconds
```

Products host route decK config:

```text
File: kong/usability-route-host-routing.yaml
Service: usability-routing-master-service
Route: usability-routing-products-host-route
Host: products.ot.local
Path: /api/v1/products/
Plugin: rate-limiting-advanced
Plugin instance: usability-routing-products-host-rate-limit
Limit: 3 requests per 60 seconds
```

Stores host route decK config:

```text
File: kong/usability-route-host-routing.yaml
Service: usability-routing-master-service
Route: usability-routing-stores-host-route
Host: stores.ot.local
Path: /api/v1/stores/
Plugin: rate-limiting-advanced
Plugin instance: usability-routing-stores-host-rate-limit
Limit: 3 requests per 60 seconds
```

## 3. Independent Route Policies

Customer guide section:

```text
3. Independent Route Policies
```

decK config:

```text
File: kong/usability-route-host-routing.yaml
Policy type: route-level rate-limiting-advanced plugins
Transactions path plugin instance: usability-routing-transactions-path-rate-limit
Transactions host plugin instance: usability-routing-transactions-host-rate-limit
Products path plugin instance: usability-routing-products-path-rate-limit
Products host plugin instance: usability-routing-products-host-rate-limit
Stores path plugin instance: usability-routing-stores-path-rate-limit
Stores host plugin instance: usability-routing-stores-host-rate-limit
Transactions limit: 10 requests per 60 seconds
Products limit: 3 requests per 60 seconds
Stores limit: 3 requests per 60 seconds
```
