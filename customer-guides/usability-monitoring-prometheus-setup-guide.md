# Usability Monitoring Prometheus Setup Guide

This guide documents how the Prometheus monitoring scene was set up for the Usability requirement:

```text
Support External Monitoring & Logging (Prometheus, ELK, Grafana)
```

This is a setup reference only. It does not include validation curls or test commands.

## Setup Summary

Kong exposes Prometheus metrics from the data plane status listener:

```text
http://<kong-data-plane-host>:8100/metrics
```

In this POC, Kong Gateway is configured so that:

```text
Kong data plane status listener: 0.0.0.0:8100
Docker host port mapping:       8100:8100
Prometheus scrape path:         /metrics
```

The Prometheus plugin is enabled globally in Konnect, so the status listener exposes gateway metrics for services, routes, consumers, status codes, bandwidth, Kong latency, and upstream latency.

## Files That Define The Setup

Primary setup reference:

```text
docs/usability-monitoring-prometheus-demo-guide.md
```

Kong data plane container configuration:

```text
docker-compose.yml
```

VM startup helper:

```text
scripts/start-kong-dataplane-vm.sh
```

Local metrics display helper:

```text
scripts/demo-usability-monitoring-prometheus.sh
```

## VM Startup Script

The startup helper used to spin up the Kong data plane container on the VM is:

```text
scripts/start-kong-dataplane-vm.sh
```

It starts the `kong-security-poc` service from `docker-compose.yml`, waits for the Kong status listener, and prints the Prometheus scrape endpoint.

The script reads the existing repo `.env` file by default:

```text
.env
```

The `.env` file must contain the Konnect data plane connection values and local TLS certificate paths expected by `docker-compose.yml`:

```text
KONG_CLUSTER_CONTROL_PLANE
KONG_CLUSTER_SERVER_NAME
KONG_CLUSTER_TELEMETRY_ENDPOINT
KONG_CLUSTER_TELEMETRY_SERVER_NAME
tls_cert
tls_key
```

To use a different env file:

```bash
OT_GRP_POC_ENV=/path/to/env ./scripts/start-kong-dataplane-vm.sh
```

## Kong Data Plane Configuration

The data plane status endpoint is configured in `docker-compose.yml` with:

```text
KONG_STATUS_LISTEN=0.0.0.0:8100
```

The port is exposed from the container to the host with:

```text
8100:8100
```

The data plane also writes proxy access and error logs to stdout/stderr:

```text
KONG_PROXY_ACCESS_LOG=/dev/stdout
KONG_PROXY_ERROR_LOG=/dev/stderr
```

Those logs can be collected by a log forwarder such as Filebeat, Fluent Bit, or another ELK-compatible collector.

## Konnect Plugin Setup

The Prometheus plugin is enabled globally in Konnect.

Because it is global, it is not tied to a single route or service-specific decK file in this repo. It applies across the gateway and allows the status listener metrics endpoint to expose Kong Gateway metrics.

The metrics endpoint includes metric families such as:

```text
kong_http_requests_total
kong_bandwidth_bytes
kong_kong_latency_ms
kong_upstream_latency_ms
```

## Prometheus Scrape Setup

Prometheus should scrape the Kong data plane status listener.

Scrape config template:

```yaml
scrape_configs:
  - job_name: kong-gateway
    metrics_path: /metrics
    static_configs:
      - targets:
          - <kong-data-plane-host>:8100
```

If Prometheus runs on the same VM as Kong:

```yaml
scrape_configs:
  - job_name: kong-gateway-local
    metrics_path: /metrics
    static_configs:
      - targets:
          - localhost:8100
```

If Prometheus runs outside the VM, replace `localhost` with the VM DNS name or IP address:

```text
<vm-ip-or-dns>:8100
```

The network, firewall, or security group must allow Prometheus to reach TCP port `8100` on the Kong data plane host.

## Grafana Setup

Grafana should use Prometheus as its data source.

Once Prometheus is scraping Kong, Grafana dashboards can visualize:

```text
Request volume by service and route
Status code distribution
Kong latency
Upstream latency
Ingress and egress bandwidth
Per-consumer metrics
```

## Customer-Facing Endpoint Format

The endpoint that should be registered in Prometheus is:

```text
http://<kong-data-plane-host>:8100/metrics
```
