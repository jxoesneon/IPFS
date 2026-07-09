# dart_ipfs Kubernetes Manifests & Helm Chart Specification

**Document ID:** `KUBERNETES_SPEC`  
**Version:** 1.0-draft  
**Target Release:** dart_ipfs v2.2  
**Status:** Draft specification for implementation  
**Maintainer Priority:** P1 APPROVED  
**Source:** `OPERATIONS_ECOSYSTEM_SPEC` section 4.3

---

## 1. Goal and Scope

The goal of this specification is to provide declarative Kubernetes deployment artifacts for `dart_ipfs` that build on the Docker image work completed in v2.2. The artifacts must make it possible to deploy a single-node `dart_ipfs` daemon to any Kubernetes cluster using either plain Kustomize manifests or a Helm chart.

Scope includes:

- A `k8s/` directory with Kustomize base manifests and environment-specific overlays.
- A Helm chart under `k8s/helm/dart-ipfs/` with production and default values.
- Security-hardened pod and container contexts (non-root, read-only root filesystem, no privilege escalation).
- Persistent volume support for the IPFS repository.
- Services for API, gateway, and libp2p swarm traffic, plus an optional headless service for peer discovery.
- Optional ingress for the gateway.
- CI jobs that lint and template the manifests and run a minikube smoke test.

Out of scope for v2.2:

- Horizontal clustering or multi-replica coordination. `replicaCount` must remain 1.
- FUSE mount support (no privileged containers or `/dev/fuse` mounts).
- Production-grade autoscaling beyond the optional HPA template.
- Custom operators or CRDs.

---

## 2. Official References

- Kubernetes concepts overview: https://kubernetes.io/docs/concepts/
- Kubernetes workloads: https://kubernetes.io/docs/concepts/workloads/
- Helm chart best practices: https://helm.sh/docs/chart_best_practices/
- Helm chart template guide: https://helm.sh/docs/chart_template_guide/
- Kustomize documentation: https://kubectl.docs.kubernetes.io/references/kustomize/
- NSA/CISA Kubernetes Hardening Guidance: https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF
- CIS Kubernetes Benchmark: https://www.cisecurity.org/benchmark/kubernetes
- Kubernetes NetworkPolicy: https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Kubernetes Ingress: https://kubernetes.io/docs/concepts/services-networking/ingress/
- Pod Security Standards: https://kubernetes.io/docs/concepts/security/pod-security-standards/

---

## 3. Current State in dart_ipfs

| Area | Current State | Gap |
|------|---------------|-----|
| Kubernetes manifests | No `k8s/` directory exists. | Cannot deploy `dart_ipfs` to a cluster declaratively. |
| Helm chart | No Helm chart exists. | No package-manager-style installation or upgrade path. |
| Kustomize overlays | None. | No environment-specific configuration (minikube, staging, production). |
| Security context | None defined. | Pods would run as root with writable root filesystems if created manually. |
| CI | No K8s CI. | No validation that manifests render or deploy correctly. |

Key dependencies:

- A published, multi-arch Docker image from `DOCKER_SPEC.md`.
- The CLI binary from `CLI_SPEC.md` so the container command is `ipfs daemon`.

---

## 4. Target State / Requirements

### 4.1 Artifact Layout (`k8s/`)

```
k8s/
├── base/
│   ├── namespace.yaml
│   ├── configmap.yaml              # default config.json
│   ├── secret.yaml                 # optional keys / bootstrap secrets
│   ├── serviceaccount.yaml
│   ├── rbac.yaml                   # minimal Role/RoleBinding if needed
│   ├── statefulset.yaml            # single-node StatefulSet
│   ├── service.yaml                # API, gateway, swarm (LoadBalancer/ClusterIP)
│   ├── headless-service.yaml       # for peer discovery
│   └── ingress.yaml                # optional gateway ingress
├── overlays/
│   ├── production/
│   ├── staging/
│   └── minikube/
└── helm/
    ├── dart-ipfs/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   ├── values-production.yaml
    │   └── templates/
    │       ├── _helpers.tpl
    │       ├── statefulset.yaml
    │       ├── service.yaml
    │       ├── ingress.yaml
    │       ├── configmap.yaml
    │       ├── secret.yaml
    │       └── serviceaccount.yaml
    └── README.md
```

### 4.2 Controller Choice

- Use a **StatefulSet** for the base manifest because the IPFS repository is stateful and benefits from stable network identity and persistent volume binding.
- `replicaCount` defaults to 1 and must be explicitly set to 1 in all overlays for v2.2. Clustering is not supported.
- **Helm is the primary, documented installation path.** Kustomize is retained as the reference/CI path and is documented with a lighter maintenance cadence.

### 4.3 Helm Chart Values

| Value | Default | Description |
|-------|---------|-------------|
| `image.repository` | `ghcr.io/dart-ipfs/dart-ipfs` | Image registry/name. |
| `image.tag` | `Chart appVersion` | Image tag. The chart `appVersion` matches `pubspec.yaml` (currently `1.11.5`). |
| `image.pullPolicy` | `IfNotPresent` | Pull policy. |
| `replicaCount` | `1` | Single-node only in v2.2. |
| `service.api.port` | `5001` | RPC API port. |
| `service.gateway.port` | `8080` | Gateway port. |
| `service.swarm.port` | `4001` | libp2p swarm TCP/UDP. |
| `persistence.enabled` | `true` | PVC for repo path. |
| `persistence.size` | `10Gi` | Initial storage size. |
| `persistence.storageClass` | `""` | Cluster default. |
| `ingress.enabled` | `false` | Optional gateway ingress. |
| `podSecurityContext` | `runAsNonRoot: true`, `fsGroup: 1000` | Security baseline. |
| `securityContext` | `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true` | Hardening. |
| `resources` | `{}` | CPU/memory limits. |
| `nodeSelector` | `{}` | Arch-specific node selection (e.g., `kubernetes.io/arch: arm64`). |
| `affinity` | `{}` | Anti-affinity rules. |
| `metrics.enabled` | `false` | Prometheus ServiceMonitor. |

**Recommended starting resource sizing:**

| Environment | CPU request | CPU limit | Memory request | Memory limit |
|-------------|-------------|-----------|----------------|--------------|
| Default / dev | `100m` | `500m` | `256Mi` | `512Mi` |
| Production | `200m` | `1000m` | `512Mi` | `1Gi` |

These are starting points and must be tuned based on workload.

### 4.4 Services

- **API service:** ClusterIP by default; expose port 5001.
- **Gateway service:** ClusterIP or LoadBalancer depending on overlay; expose port 8080.
- **Swarm service:** NodePort or LoadBalancer for port 4001/tcp **and** 4001/udp to allow external peers to dial in. Some cloud load balancers do not support UDP; document this limitation.
- **Headless service:** For stable peer identity within the StatefulSet.

### 4.5 Ingress

- Optional ingress for the gateway. Path-based ingress is required; subdomain-based ingress is optional.
- Ingress must not expose the RPC API (`5001`) unless behind an authenticated proxy.
- Ingress annotations should support common ingress controllers (nginx, traefik).

### 4.6 ConfigMap and Secret

- `configmap.yaml` contains the default `config.json`.
- `secret.yaml` holds optional bootstrap keys or RPC auth tokens. Secrets must not be placed in ConfigMaps.
- Sensitive config must be mounted as files or injected from Kubernetes Secrets, never baked into the image.

### 4.7 Production Values Snippet

`values-production.yaml` must set:

```yaml
replicaCount: 1

image:
  repository: ghcr.io/dart-ipfs/dart-ipfs
  tag: "1.11.5"
  pullPolicy: IfNotPresent

persistence:
  enabled: true
  size: 10Gi

podSecurityContext:
  runAsNonRoot: true
  fsGroup: 1000

securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]

resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi

ingress:
  enabled: false
```

---

## 5. Detailed Acceptance Criteria

1. `kubectl apply -k k8s/overlays/minikube/` deploys a working `dart_ipfs` node in a local cluster.
2. `helm install dart-ipfs k8s/helm/dart-ipfs --set image.tag=edge` deploys a working node.
3. `helm lint k8s/helm/dart-ipfs` passes with no warnings or errors.
4. `helm template k8s/helm/dart-ipfs` renders valid YAML.
5. `kustomize build k8s/overlays/production/` produces valid Kubernetes manifests.
6. The pod `readinessProbe` uses `ipfs id` or `/api/v0/id` and succeeds before the pod is marked ready.
7. Nodes in different clusters can dial each other via the published swarm port.
8. The production overlay uses a `StatefulSet` with a `PersistentVolumeClaim` and a read-only root filesystem.
9. Gateway ingress is disabled by default and must be explicitly enabled.
10. `helm template` with default values renders a `StatefulSet` with `replicas: 1`, `securityContext.runAsNonRoot: true`, and `securityContext.readOnlyRootFilesystem: true`.
11. Gateway ingress is disabled by default and requires `ingress.enabled=true` plus an explicit `ingress.hosts` entry to be created.
12. `helm upgrade` does not delete or recreate the existing PVC (verified by `helm.sh/resource-policy: keep` or equivalent annotation).
13. CI validates every manifest change with `helm lint`, `helm template`, `kustomize build`, and a minikube smoke test. The Kubernetes CI is **non-blocking for v2.2.0** and becomes release-blocking only after the first successful minikube smoke run on `main`.

---

## 6. Security Considerations

- Pod security context: `runAsNonRoot: true`, `fsGroup: 1000`.
- Container security context: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `runAsUser: 1000`, `runAsGroup: 1000`, and a minimal `capabilities` drop (e.g., `drop: ["ALL"]`).
- No privileged containers, no host networking, and no `hostPath` volumes unless in an explicit debug overlay.
- Secrets for bootstrap keys or RPC auth must be stored in Kubernetes Secrets, not ConfigMaps.
- NetworkPolicy should restrict ingress to API and gateway ports only; the swarm port may be exposed via a Service but should be documented as externally reachable.
- Do not mount the Docker socket or grant unnecessary RBAC permissions.
- Use Pod Security Standards baseline or restricted profile where possible.
- Gateway ingress must not expose the RPC API. If API access is required, it should be behind an authenticated proxy.

---

## 7. Testing Strategy

### 7.1 Static Manifest Validation

- `helm lint` on the chart.
- `helm template` against `values.yaml` and `values-production.yaml`.
- `kustomize build` for each overlay.
- YAML schema validation with `kubeconform` or `kubeval` if available.

### 7.2 Smoke Tests

- Start minikube or use a lightweight Kubernetes distribution (e.g., kind).
- Deploy the minikube overlay and verify the pod becomes ready.
- Query `/api/v0/id` via the API service and confirm valid JSON.
- Expose the gateway and confirm a pinned or uploaded CID is retrievable.
- Verify peer dialability through the swarm service.

### 7.3 CI Pipeline

- Create `.github/workflows/k8s.yml` triggered:
  - On PRs touching `k8s/` or `.github/workflows/k8s.yml`.
  - Nightly against `main`.
- Jobs:
  - `helm lint` and `helm template`.
  - `kustomize build` for all overlays.
  - Minikube smoke test with a published or locally built `edge` image.
- The pipeline is **non-blocking for v2.2.0** and becomes release-blocking only after the first successful minikube smoke run on `main`.

---

## 8. Dependencies and Ordering

- **Prerequisites:**
  - Docker image built and published automatically (see `DOCKER_SPEC.md`).
  - CLI binary stable (see `CLI_SPEC.md`).
  - Chart `appVersion` matches the package version (`1.11.5` at the time of writing).
- **Order:** Kubernetes is P1 and must start **after** Docker CI is complete and images are auto-published. It is part of the v2.2 rc / optional v2.2.x phase.
- **Downstream consumers:**
  - Production deployment guides in `doc/deploy.md` (to be created).
  - Potential cloud marketplace listings in v3.0.

---

## 9. Backward Compatibility Notes

- Kubernetes manifests are a new deliverable; there is no prior artifact to migrate from.
- The Helm chart will follow semantic versioning independent of the application where practical, but the chart's `appVersion` should match the Docker image tag for a given release.
- Overlays should be additive. Production overlays may set stricter security contexts and resource limits than the base.
- Future releases (v3.0) may introduce clustering or operator-based deployments. v2.2 manifests must be designed so that a single-replica StatefulSet can be upgraded cleanly without requiring manual data migration.
- PersistentVolumeClaims must not be deleted during chart upgrades so the IPFS repository survives version updates.
