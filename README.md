# zig-metrics

A Prometheus-compatible metrics exporter written in Zig.

Exposes CPU, memory, network, and disk metrics scraped from `/proc` on a simple HTTP server.

## Endpoints

| Path | Description |
|------|-------------|
| `GET /metrics` | Prometheus text-format metrics |
| `GET /health` | Health check — returns `OK` |

## Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `system_cpu_usage_percent` | gauge | CPU usage % (delta between scrapes) |
| `system_memory_total_bytes` | gauge | Total installed memory |
| `system_memory_free_bytes` | gauge | Unallocated memory |
| `system_memory_available_bytes` | gauge | Memory available for new allocations |
| `system_memory_used_bytes` | gauge | Memory in use |
| `system_network_receive_bytes_total` | counter | Bytes received per interface |
| `system_network_transmit_bytes_total` | counter | Bytes transmitted per interface |
| `system_network_receive_packets_total` | counter | Packets received per interface |
| `system_network_transmit_packets_total` | counter | Packets transmitted per interface |
| `system_disk_reads_completed_total` | counter | Read ops per device |
| `system_disk_writes_completed_total` | counter | Write ops per device |
| `system_disk_read_bytes_total` | counter | Bytes read per device |
| `system_disk_written_bytes_total` | counter | Bytes written per device |

## Building

Requires **Zig 0.16.0+**.

```sh
zig build          # debug build → zig-out/bin/zig-metrics
zig build test     # run tests
zig build run      # build and run (listens on :9090)

# Static release binary for Linux x86_64
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl
```

## Local stack (Docker Compose)

Starts zig-metrics + Prometheus + Grafana:

```sh
docker compose up --build
```

| Service | URL |
|---------|-----|
| zig-metrics | http://localhost:9090/metrics |
| Prometheus | http://localhost:9091 |
| Grafana | http://localhost:3000 (anon admin) |

> The compose file mounts host `/proc` so you see real system-level metrics.

## Kubernetes (k3s)

```sh
# Update image name in k8s/deployment.yaml first
kubectl apply -f k8s/
```

A `ServiceMonitor` is included for Prometheus Operator (kube-prometheus-stack).

## CI/CD

| Workflow | Trigger | Action |
|----------|---------|--------|
| `ci.yml` | push / PR to main | `zig build test` + `zig build` |
| `release.yml` | push `v*` tag | Build amd64 + arm64 binaries, create GitHub Release |
| `docker.yml` | push to main / tag | Build + push multi-arch image to GHCR |
