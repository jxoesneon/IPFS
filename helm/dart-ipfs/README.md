# dart-ipfs Helm Chart

A production-oriented Helm chart for deploying the `dart_ipfs` daemon on Kubernetes.

## TL;DR

```bash
helm install dart-ipfs ./helm/dart-ipfs
```

## Prerequisites

- Kubernetes 1.24+
- Helm 3.12+
- A published `dart_ipfs` container image (default: `ghcr.io/jxoesneon/dart-ipfs:1.11.5`)

## Installing

```bash
# Install with default values
helm install dart-ipfs ./helm/dart-ipfs

# Install with a specific image tag
helm install dart-ipfs ./helm/dart-ipfs --set image.tag=edge

# Install with a custom values file
helm install dart-ipfs ./helm/dart-ipfs -f values-production.yaml
```

## Uninstalling

```bash
helm uninstall dart-ipfs
```

## Configuration

The following table lists the configurable parameters and their defaults.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `replicaCount` | `1` | Number of replicas. Keep `1` because dart_ipfs v2.2 is not clustered. |
| `image.repository` | `ghcr.io/jxoesneon/dart-ipfs` | Image registry/repository. |
| `image.tag` | `""` | Image tag; defaults to `Chart.appVersion`. |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy. |
| `service.type` | `ClusterIP` | Service type for the combined service. |
| `service.api.port` | `5001` | RPC API port. |
| `service.gateway.port` | `8080` | HTTP gateway port. |
| `service.swarm.port` | `4001` | libp2p swarm TCP/UDP port. |
| `service.metrics.port` | `8081` | Prometheus metrics port. |
| `swarmService.enabled` | `false` | Create a dedicated swarm service (LoadBalancer/NodePort). |
| `ingress.enabled` | `false` | Expose the gateway via Ingress. The RPC API is never exposed. |
| `persistence.enabled` | `true` | Enable a PVC for the IPFS repository. |
| `persistence.size` | `10Gi` | PVC size. |
| `persistence.storageClass` | `""` | Storage class for the PVC. |
| `podSecurityContext` | runAsNonRoot, uid/gid 1000 | Pod security context. |
| `securityContext` | readOnlyRootFilesystem, drop ALL | Container security context. |
| `networkPolicy.enabled` | `true` | Restrict pod ingress/egress. |
| `autoscaling.enabled` | `false` | Horizontal Pod Autoscaler. |
| `podDisruptionBudget.enabled` | `false` | Pod Disruption Budget. |
| `metrics.enabled` | `false` | Enable Prometheus ServiceMonitor. |

## Security

The chart follows the hardening requirements from `OPERATIONS_ECOSYSTEM_SPEC`:

- Non-root user (`runAsUser: 1000`).
- Read-only root filesystem.
- No privilege escalation.
- All capabilities dropped.
- `seccompProfile` set to `RuntimeDefault`.
- Secrets are mounted for sensitive material (identity seed, API token, keystore password).
- The RPC API (`port 5001`) is never exposed via Ingress.

## Exposing the Swarm Port

To let external libp2p peers dial the node, enable the dedicated swarm service:

```bash
helm install dart-ipfs ./helm/dart-ipfs \
  --set swarmService.enabled=true \
  --set swarmService.type=LoadBalancer
```

## Providing Secrets

Do not commit real secrets. Either use `secrets.existingSecret` to reference an
externally managed Secret, or pass values securely at install time:

```bash
helm install dart-ipfs ./helm/dart-ipfs \
  --set secrets.create=true \
  --set secrets.libp2pIdentitySeed="$(openssl rand -base64 32)"
```

## Gateway Ingress

Expose the gateway (never the RPC API) via Ingress:

```bash
helm install dart-ipfs ./helm/dart-ipfs \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=gateway.example.com \
  --set ingress.hosts[0].paths[0].path=/
```

## Validation

```bash
helm lint ./helm/dart-ipfs
helm template dart-ipfs ./helm/dart-ipfs
```
