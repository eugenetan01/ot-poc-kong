#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${OT_GRP_POC_ENV:-${ROOT_DIR}/.env}"
COMPOSE_FILE="${COMPOSE_FILE:-${ROOT_DIR}/docker-compose.yml}"
SERVICE_NAME="${SERVICE_NAME:-kong-security-poc}"
STATUS_URL="${STATUS_URL:-http://localhost:8100/status}"
METRICS_URL="${METRICS_URL:-http://localhost:8100/metrics}"

required_env=(
  KONG_CLUSTER_CONTROL_PLANE
  KONG_CLUSTER_SERVER_NAME
  KONG_CLUSTER_TELEMETRY_ENDPOINT
  KONG_CLUSTER_TELEMETRY_SERVER_NAME
  tls_cert
  tls_key
)

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE" >&2
  echo "Create it with the Konnect data plane values and TLS certificate paths required by docker-compose.yml." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

missing=()
for name in "${required_env[@]}"; do
  if [ -z "${!name:-}" ]; then
    missing+=("$name")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Missing required values in $ENV_FILE:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

if [ ! -f "$tls_cert" ]; then
  echo "TLS certificate file not found: $tls_cert" >&2
  exit 1
fi

if [ ! -f "$tls_key" ]; then
  echo "TLS key file not found: $tls_key" >&2
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  compose=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  compose=(docker-compose)
else
  echo "Docker Compose is not installed. Install Docker Compose before running this script." >&2
  exit 1
fi

echo "Starting Kong data plane service: $SERVICE_NAME"
echo "Compose file: $COMPOSE_FILE"
echo "Env file: $ENV_FILE"

"${compose[@]}" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d "$SERVICE_NAME"

echo
echo "Container status:"
"${compose[@]}" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps "$SERVICE_NAME"

echo
echo "Waiting for Kong status listener: $STATUS_URL"
ready=0
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if curl -fsS "$STATUS_URL" >/tmp/kong-dataplane-status.json 2>/tmp/kong-dataplane-status.err; then
    ready=1
    break
  fi

  echo "Attempt $attempt: Kong status endpoint is not ready yet"
  sleep 5
done

if [ "$ready" != "1" ]; then
  echo "Kong did not become ready at $STATUS_URL" >&2
  echo "Latest curl error:" >&2
  cat /tmp/kong-dataplane-status.err >&2 || true
  echo "Recent container logs:" >&2
  "${compose[@]}" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" logs --tail=80 "$SERVICE_NAME" >&2 || true
  exit 1
fi

echo "Kong status listener is ready."

if curl -fsS "$METRICS_URL" >/tmp/kong-dataplane-metrics.txt 2>/tmp/kong-dataplane-metrics.err; then
  echo "Prometheus metrics endpoint is available: $METRICS_URL"
  echo
  echo "Sample metric families:"
  rg -n "^(# HELP kong_|# TYPE kong_|kong_http_requests_total|kong_kong_latency_ms|kong_upstream_latency_ms|kong_bandwidth_bytes)" \
    /tmp/kong-dataplane-metrics.txt | sed -n '1,20p' || true
else
  echo "Kong is running, but the metrics endpoint did not return successfully: $METRICS_URL" >&2
  echo "This usually means the global Prometheus plugin has not been enabled or propagated yet." >&2
  cat /tmp/kong-dataplane-metrics.err >&2 || true
fi

echo
echo "Kong proxy listener: http://<vm-ip-or-dns>:8000"
echo "Kong TLS proxy listener: https://<vm-ip-or-dns>:8443"
echo "Prometheus scrape endpoint: http://<vm-ip-or-dns>:8100/metrics"
