# OT POC Kong

This repository packages the customer-facing Kong POC material for OT Group.

It contains customer guides, scene-to-decK mappings, original presenter docs, the Kong data plane Docker Compose file, a VM startup helper, and a sanitized Konnect dump.

## Directory Layout

```text
customer-guides/
```

Customer-facing guides. These are the documents to use when validating the POC scenes. Most guides are execution focused, while the Prometheus guide is setup focused.

```text
deck/
```

Scene-to-configuration mappings. Each file explains which decK config file, route, service, plugin, or generated pipeline artifact backs each customer guide section.

```text
docs/
```

Original presenter/demo guides. These contain more implementation context and presenter notes.

```text
scripts/start-kong-dataplane-vm.sh
```

Startup helper for the VM. It starts the Kong data plane container from `docker-compose.yml`, waits for the status listener, and checks the Prometheus metrics endpoint.

```text
docker-compose.yml
```

Docker Compose definition for the Kong Konnect data plane container.

```text
dump/
```

Sanitized decK dump of the current Konnect state.

The dump file is:

```text
dump/konnect-current-sanitized.yaml
```

It was generated with `deck gateway dump --sanitize` so sensitive fields are not published in this public repository.

## How To Use The Guides

Start with `customer-guides/`.

Recommended order:

```text
customer-guides/security-rfp-test-guide.md
customer-guides/usability-route-host-routing-test-guide.md
customer-guides/usability-api-versioning-cicd-test-guide.md
customer-guides/usability-monitoring-prometheus-setup-guide.md
customer-guides/performance-checkout-1000-load-test-guide.md
customer-guides/performance-store-rate-limit-service-protection-test-guide.md
```

When a guide references its implementation, open the matching file in `deck/`.

Example:

```text
customer-guides/security-rfp-test-guide.md
deck/security-rfp-scene-map.md
```

## Starting Kong On The VM

The VM startup helper is:

```bash
./scripts/start-kong-dataplane-vm.sh
```

By default, it reads:

```text
.env
```

To use a different env file:

```bash
OT_GRP_POC_ENV=/path/to/env ./scripts/start-kong-dataplane-vm.sh
```

## Required Local Secrets And Files

Secrets and private keys are intentionally not included in this public repository.

To start the Kong data plane on the VM, provide an `.env` file with:

```text
KONG_CLUSTER_CONTROL_PLANE
KONG_CLUSTER_SERVER_NAME
KONG_CLUSTER_TELEMETRY_ENDPOINT
KONG_CLUSTER_TELEMETRY_SERVER_NAME
tls_cert
tls_key
```

The `tls_cert` and `tls_key` values must point to the Konnect data plane certificate and private key files on the VM.

For decK operations against Konnect, provide:

```text
KONNECT_PAT
KONNECT_REGION
KONNECT_CONTROL_PLANE_NAME
```

Some local scripts from the original working repo used `TF_VAR_control_plane_name` for the control plane name.

For Google OIDC scenes, the original setup used Google OAuth client credentials and a session secret. If those scenes need to be re-synced rather than only tested, provide the corresponding client ID, client secret, and session secret through the sync process.

For the mTLS security test, provide the trusted client certificate and key referenced by the guide:

```text
certs/pos-terminal-001.crt
certs/pos-terminal-001.key
```

For the performance store rate-limit tests, provide valid Google ID tokens for onboarded Kong Consumers when running bearer-token burst tests.

## Prometheus

Kong exposes Prometheus metrics on the data plane status listener:

```text
http://<kong-data-plane-host>:8100/metrics
```

The Prometheus setup reference is:

```text
customer-guides/usability-monitoring-prometheus-setup-guide.md
```

## Notes

This repository is documentation and runtime helper packaging. It does not include private `.env` files, OAuth client secret JSON files, Konnect personal access tokens, private TLS keys, or generated local test logs.
