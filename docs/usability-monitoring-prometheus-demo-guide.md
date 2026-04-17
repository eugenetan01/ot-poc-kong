# Usability Monitoring Prometheus Demo Guide

This scene demonstrates:

```text
Support External Monitoring & Logging (Prometheus, ELK, Grafana)
```

For Prometheus, Kong exposes a metrics endpoint from the data plane status listener:

```text
http://<kong-data-plane-host>:8100/metrics
```

In this local POC environment:

```text
http://localhost:8100/metrics
```

## What Is Already Configured

The Kong data plane container exposes the status listener:

```text
KONG_STATUS_LISTEN=0.0.0.0:8100
Docker port mapping: 8100:8100
```

The Prometheus plugin is enabled globally in Konnect, so the `/metrics` endpoint returns gateway metrics for services, routes, consumers, status codes, bandwidth, and latency.

## Validate The Endpoint

Run:

```bash
./scripts/demo-usability-monitoring-prometheus.sh
```

Or directly:

```bash
curl -i http://localhost:8100/metrics
```

Expected:

```text
HTTP/1.1 200 OK
Content-Type: text/plain; charset=UTF-8
```

Sample metric families:

```text
kong_bandwidth_bytes
kong_http_requests_total
kong_kong_latency_ms
kong_upstream_latency_ms
```

## Customer Scrape Endpoint

Give the customer this endpoint format:

```text
http://<kong-data-plane-host>:8100/metrics
```

If Prometheus runs on the same VM as Kong:

```text
http://localhost:8100/metrics
```

If Prometheus runs outside the VM:

```text
http://<vm-ip-or-dns>:8100/metrics
```

The network/security group/firewall must allow Prometheus to reach TCP port `8100` on the Kong data plane host.

## Prometheus Scrape Config

```yaml
scrape_configs:
  - job_name: kong-gateway
    metrics_path: /metrics
    static_configs:
      - targets:
          - <kong-data-plane-host>:8100
```

Local POC example:

```yaml
scrape_configs:
  - job_name: kong-gateway-local
    metrics_path: /metrics
    static_configs:
      - targets:
          - localhost:8100
```

## Grafana

Grafana should use Prometheus as its data source. Once Prometheus is scraping Kong, dashboards can chart:

```text
Request volume by service and route
Status codes
Kong latency
Upstream latency
Ingress and egress bandwidth
Per-consumer metrics
```

## ELK

For ELK, use Kong proxy logs from the data plane container. In this POC Docker setup:

```text
KONG_PROXY_ACCESS_LOG=/dev/stdout
KONG_PROXY_ERROR_LOG=/dev/stderr
```

An ELK/Filebeat/Fluent Bit agent can collect container stdout/stderr and ship those logs to Elasticsearch.
