# Usability API Versioning And CI/CD Customer Test Guide

This guide is for customer validation of the API versioning, canary, rollback, and CI/CD usability requirement. Kong Gateway, Konnect configuration, CI/CD pipeline, routes, plugins, upstream services, and infrastructure are assumed to already be set up.

The customer only needs to run the curl commands below and compare the result with the expected outcome.

## Test Endpoint

All curl examples use the public load balancer hostname:

```text
https://apidev-kong.ot.id
```

## 1. API Versioning

Requirement: Kong must support versioned API routes so existing clients can stay on v1 while new clients can use v2.

Routes:

```text
/usability/v1/master/catalog/
/usability/v2/master/catalog/
```

decK config: `/Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/dist/kong.yaml` -> routes `OT_Group_Usability_Master_Catalog_API-getMasterCatalogV1` and `OT_Group_Usability_Master_Catalog_API-getMasterCatalogV2`. Source OpenAPI: `/Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/openapi/usability-master-catalog.yaml`. Full mapping: `deck/usability-api-versioning-cicd-scene-map.md`.

### Test 1.1: v1 Catalog Route Is Available

Run:

```bash
curl -i "https://apidev-kong.ot.id/usability/v1/master/catalog/?status=active&page=1&size=1"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
The v1 route remains available and returns the WOLU Master Products response.
```

### Test 1.2: v2 Catalog Route Is Available

Run:

```bash
curl -i "https://apidev-kong.ot.id/usability/v2/master/catalog/?status=active&page=1&size=1"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
The v2 route is available and returns the WOLU Master Stores response.
```

## 2. Canary-Controlled Public Route

Requirement: Kong must support controlled rollout from v1 to v2 through a gateway policy.

Route:

```text
/usability/master/catalog/
```

decK config: `/Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/dist/kong.yaml` -> route `OT_Group_Usability_Master_Catalog_API-getMasterCatalogPublic`, plugin instance `usability-master-public-v2-canary`. Plugin overlay source: `/Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/demo-scenes/usability-deploy-plugins.yaml`. Full mapping: `deck/usability-api-versioning-cicd-scene-map.md`.

### Test 2.1: Public Route Returns Both v1 And v2 Responses Over Repeated Calls

Run:

```bash
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  echo "request $i"
  curl -s "https://apidev-kong.ot.id/usability/master/catalog/?status=active&page=1&size=1"
  echo
done
```

Expected result:

```text
Some responses contain Product catalog fields.
Some responses contain Store catalog fields.
```

Pass criteria:

```text
The public route stays stable while Kong shifts a portion of traffic from the default Products upstream to the Stores upstream.
```

## 3. Rollback Runtime Validation

Requirement: rollback must restore the public route to the stable v1 behavior and remove the v2 route.

Run these tests after the rollback workflow has completed successfully.

Rollback decK config: generated from `/Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/openapi/usability-master-catalog-rollback.yaml` and `/Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/demo-scenes/usability-rollback-plugins.yaml`. Full mapping: `deck/usability-api-versioning-cicd-scene-map.md`.

### Test 3.1: Public Route Returns Stable v1 After Rollback

Run:

```bash
curl -i "https://apidev-kong.ot.id/usability/master/catalog/?status=active&page=1&size=1"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
The public route returns the WOLU Master Products response after rollback.
```

### Test 3.2: v2 Route Is Removed After Rollback

Run:

```bash
curl -i "https://apidev-kong.ot.id/usability/v2/master/catalog/?status=active&page=1&size=1"
```

Expected result:

```text
HTTP/1.1 404 Not Found
```

Pass criteria:

```text
The v2 route is no longer available after rollback.
```

## 4. CI/CD Evidence

Requirement: API and gateway configuration changes must be managed through Git and deployed through CI/CD.

This requirement is validated by checking the generated runtime behavior in the tests above. The exact Git, OpenAPI, plugin overlay, workflow, and generated decK files are listed in:

```text
deck/usability-api-versioning-cicd-scene-map.md
```
