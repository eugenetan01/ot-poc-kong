# Usability API Versioning And CI/CD Customer Test Guide

This guide is for customer validation of the API versioning, canary, rollback, and CI/CD usability requirement. Kong Gateway, Konnect configuration, CI/CD pipeline, routes, plugins, upstream services, and infrastructure are assumed to already be set up.

Use this guide in this order:

```text
1. Review the CI/CD source repository and workflow.
2. Reset any previous CI/CD demo state.
3. Run the deploy workflow.
4. Validate the deployed versioned and canary routes.
5. Run the rollback workflow.
6. Validate the rollback result.
```

## 1. CI/CD Repository And Evidence

Requirement: API and gateway configuration changes must be managed through Git and deployed through CI/CD.

CI/CD repository:

```text
https://github.com/eugenetan01/ot-grp-poc-cicd
```

GitHub Actions workflow:

```text
https://github.com/eugenetan01/ot-grp-poc-cicd/actions/workflows/usability-rfp-demo.yaml
```

Important source files:

```text
openapi/usability-master-catalog.yaml
openapi/usability-master-catalog-rollback.yaml
demo-scenes/usability-deploy-plugins.yaml
demo-scenes/usability-rollback-plugins.yaml
.github/workflows/usability-rfp-demo.yaml
scripts/build-kong-config.sh
```

Generated decK files:

```text
dist/kong.raw.yaml
dist/kong.yaml
```

Full implementation mapping:

```text
deck/usability-api-versioning-cicd-scene-map.md
```

## 2. Reset Previous CI/CD Demo State

Before running the deploy workflow, reset any existing API versioning CI/CD entities that may have been created by a previous run.

This reset is scoped to entities that have both tags:

```text
usability
orangtua
```

Run:

```bash
deck gateway reset \
  --select-tag usability \
  --select-tag orangtua \
  --konnect-token "$KONNECT_PAT" \
  --konnect-control-plane-name "$KONNECT_CONTROL_PLANE_NAME" \
  --konnect-addr "$KONNECT_REGION" \
  --force
```

Expected result:

```text
decK deletes the previously deployed CI/CD demo entities that match both tags.
```

Pass criteria:

```text
The control plane is clean for the API versioning CI/CD demo before the deploy workflow runs.
```

Important:

```text
Do not run an untagged deck gateway reset. The command above is intentionally scoped with --select-tag usability and --select-tag orangtua.
```

## 3. Run The Deploy Workflow

Requirement: demonstrate that the versioned API routes and canary policy are deployed through GitHub Actions and decK.

Open the GitHub Actions workflow:

```text
https://github.com/eugenetan01/ot-grp-poc-cicd/actions/workflows/usability-rfp-demo.yaml
```

Select:

```text
Run workflow
```

Use these inputs:

```text
Branch: master
mode: deploy
apply: true
```

Expected workflow stages:

```text
Checkout repository
Setup decK
Convert OAS to Kong config
Add plugins overlay
Validate generated Kong config
Upload generated Kong config
Preview Konnect changes with decK diff
Sync Konnect with decK
```

Expected source files used by the deploy workflow:

```text
openapi/usability-master-catalog.yaml
demo-scenes/usability-deploy-plugins.yaml
```

Expected generated gateway behavior:

```text
/usability/v1/master/catalog/ returns WOLU Master Products
/usability/v2/master/catalog/ returns WOLU Master Stores
/usability/master/catalog/ defaults to Products and canaries 50% to Stores
```

In the workflow run, open the uploaded artifact:

```text
generated-kong-config
```

The artifact contains:

```text
dist/kong.raw.yaml
dist/kong.yaml
```

What to point out:

```text
dist/kong.raw.yaml is generated from the OpenAPI contract.
dist/kong.yaml is the final gateway config after the plugin overlay is applied.
The public route has the canary plugin instance usability-master-public-v2-canary.
```

## 4. Validate The Deployed Runtime Routes

Run these tests after the deploy workflow has completed successfully.

All curl examples use the public load balancer hostname:

```text
https://apidev-kong.ot.id
```

### Test 4.1: v1 Catalog Route Is Available

Requirement: existing clients can stay on v1.

Route:

```text
/usability/v1/master/catalog/
```

decK config: `dist/kong.yaml` in `https://github.com/eugenetan01/ot-grp-poc-cicd` -> route `OT_Group_Usability_Master_Catalog_API-getMasterCatalogV1`. Source OpenAPI: `openapi/usability-master-catalog.yaml`. Full mapping: `deck/usability-api-versioning-cicd-scene-map.md`.

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

### Test 4.2: v2 Catalog Route Is Available

Requirement: new clients can use v2 without breaking v1.

Route:

```text
/usability/v2/master/catalog/
```

decK config: `dist/kong.yaml` in `https://github.com/eugenetan01/ot-grp-poc-cicd` -> route `OT_Group_Usability_Master_Catalog_API-getMasterCatalogV2`. Source OpenAPI: `openapi/usability-master-catalog.yaml`. Full mapping: `deck/usability-api-versioning-cicd-scene-map.md`.

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

### Test 4.3: Public Route Uses Canary Policy

Requirement: Kong supports controlled rollout from v1 to v2 through a gateway policy.

Route:

```text
/usability/master/catalog/
```

decK config: `dist/kong.yaml` in `https://github.com/eugenetan01/ot-grp-poc-cicd` -> route `OT_Group_Usability_Master_Catalog_API-getMasterCatalogPublic`, plugin instance `usability-master-public-v2-canary`. Plugin overlay source: `demo-scenes/usability-deploy-plugins.yaml`. Full mapping: `deck/usability-api-versioning-cicd-scene-map.md`.

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

## 5. Run The Rollback Workflow

Requirement: rollback must restore the public route to the stable v1 behavior and remove the v2 route.

Open the same GitHub Actions workflow:

```text
https://github.com/eugenetan01/ot-grp-poc-cicd/actions/workflows/usability-rfp-demo.yaml
```

Select:

```text
Run workflow
```

Use these inputs:

```text
Branch: master
mode: rollback
apply: true
```

Expected source files used by the rollback workflow:

```text
openapi/usability-master-catalog-rollback.yaml
demo-scenes/usability-rollback-plugins.yaml
```

Rollback decK config: generated from `openapi/usability-master-catalog-rollback.yaml` and `demo-scenes/usability-rollback-plugins.yaml` in `https://github.com/eugenetan01/ot-grp-poc-cicd`. Full mapping: `deck/usability-api-versioning-cicd-scene-map.md`.

Expected rollback behavior:

```text
/usability/master/catalog/ returns stable v1 Products
/usability/v1/master/catalog/ remains available
/usability/v2/master/catalog/ is removed
The canary plugin is removed from the public route
```

## 6. Validate The Rollback Runtime Routes

Run these tests after the rollback workflow has completed successfully.

### Test 6.1: Public Route Returns Stable v1 After Rollback

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

### Test 6.2: v2 Route Is Removed After Rollback

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

## 7. Re-Deploy After Rollback

To return the environment to the versioned/canary state, run the workflow again with:

```text
Branch: master
mode: deploy
apply: true
```

After the deploy workflow succeeds, rerun section 4 of this guide.
