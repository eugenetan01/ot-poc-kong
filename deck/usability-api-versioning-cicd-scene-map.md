# Usability API Versioning And CI/CD Scene To decK Config Map

This file maps each customer test scene in `customer-guides/usability-api-versioning-cicd-test-guide.md` to the Git, OpenAPI, plugin overlay, workflow, and generated decK configuration that implements it.

The source repository for this scene is:

```text
/Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd
```

## 1. API Versioning

Customer guide section:

```text
1. API Versioning
```

Source of truth:

```text
OpenAPI file: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/openapi/usability-master-catalog.yaml
Build helper: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/scripts/build-kong-config.sh
Workflow: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/.github/workflows/usability-rfp-demo.yaml
Generated raw decK config: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/dist/kong.raw.yaml
Generated final decK config: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/dist/kong.yaml
```

v1 route generated decK config:

```text
File: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/dist/kong.yaml
Service: OT_Group_Usability_Master_Catalog_API-getMasterCatalogV1
Route: OT_Group_Usability_Master_Catalog_API-getMasterCatalogV1
Route path: ~/usability/v1/master/catalog/$
Upstream host: wolu-master-service-175096896148.asia-southeast2.run.app
Upstream path: /api/v1/products/
Tags: usability, orangtua
```

v2 route generated decK config:

```text
File: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/dist/kong.yaml
Service: OT_Group_Usability_Master_Catalog_API-getMasterCatalogV2
Route: OT_Group_Usability_Master_Catalog_API-getMasterCatalogV2
Route path: ~/usability/v2/master/catalog/$
Upstream host: wolu-master-service-175096896148.asia-southeast2.run.app
Upstream path: /api/v1/stores/
Tags: usability, orangtua
```

## 2. Canary-Controlled Public Route

Customer guide section:

```text
2. Canary-Controlled Public Route
```

Source of truth:

```text
OpenAPI file: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/openapi/usability-master-catalog.yaml
Plugin overlay: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/demo-scenes/usability-deploy-plugins.yaml
Workflow: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/.github/workflows/usability-rfp-demo.yaml
Generated final decK config: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/dist/kong.yaml
```

Public route generated decK config:

```text
File: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/dist/kong.yaml
Service: OT_Group_Usability_Master_Catalog_API-getMasterCatalogPublic
Route: OT_Group_Usability_Master_Catalog_API-getMasterCatalogPublic
Route path: ~/usability/master/catalog/$
Default upstream host: wolu-master-service-175096896148.asia-southeast2.run.app
Default upstream path: /api/v1/products/
Tags: usability, orangtua
```

Canary plugin generated decK config:

```text
File: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/dist/kong.yaml
Plugin: canary
Plugin instance: usability-master-public-v2-canary
Percentage: 50
Hash: none
Canary upstream host: wolu-master-service-175096896148.asia-southeast2.run.app
Canary upstream path: /api/v1/stores/
Upstream fallback: false
Tags: usability, orangtua
```

## 3. Rollback Runtime Validation

Customer guide section:

```text
3. Rollback Runtime Validation
```

Rollback source of truth:

```text
Rollback OpenAPI file: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/openapi/usability-master-catalog-rollback.yaml
Rollback plugin overlay: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/demo-scenes/usability-rollback-plugins.yaml
Workflow: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/.github/workflows/usability-rfp-demo.yaml
Generated final decK config after rollback build: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/dist/kong.yaml
```

Expected rollback state:

```text
Public route remains: /usability/master/catalog/
Public route upstream path: /api/v1/products/
v1 route remains: /usability/v1/master/catalog/
v2 route removed: /usability/v2/master/catalog/
Canary plugin removed: usability-master-public-v2-canary
```

## 4. CI/CD Evidence

Customer guide section:

```text
4. CI/CD Evidence
```

Pipeline config:

```text
Workflow file: /Users/eugene.tan@konghq.com/gh/ot-grp-poc-cicd/.github/workflows/usability-rfp-demo.yaml
Workflow name: Usability RFP GitOps Deploy
Job name: OAS to Kong config, diff, sync
decK setup: kong/setup-deck@v1 with version 1.53.2
```

Pipeline stages:

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

Pipeline commands:

```text
deck file openapi2kong --spec <deploy-or-rollback-openapi> --output-file dist/kong.raw.yaml --select-tag usability --select-tag orangtua --inso-compatible
deck file add-plugins -s dist/kong.raw.yaml -o dist/kong.yaml <deploy-or-rollback-plugin-overlay>
deck file validate dist/kong.yaml
deck gateway diff dist/kong.yaml --select-tag usability --select-tag orangtua
deck gateway sync dist/kong.yaml --select-tag usability --select-tag orangtua --yes
```
