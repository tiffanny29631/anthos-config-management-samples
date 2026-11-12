# KNV2006 repro: implicit namespace handoff between two RootSyncs

Reproduces the `RootSync/platform-fp` deadlock from b/579721612 without GDCE.

Two RootSyncs mirror the customer's Fleet Packages:

| Dir | Mirrors | Contents |
|---|---|---|
| `platform-fp/` | `platform-fp` | Objects in `vm-workloads` and `platform-nats`, no `Namespace` objects, plus a `Widget` custom resource whose CRD isn't installed yet |
| `cluster-fp/` | `cluster-fp` | `Namespace/vm-workloads`, `Namespace/platform-nats`, and the `widgets.repro.example.com` CRD |

The race is forced by syncing `platform-fp` first, then `cluster-fp`.

## Setup

```bash
kind create cluster --name knv2006
kubectl apply -f https://github.com/GoogleContainerTools/kpt-config-sync/releases/download/v1.22.2/config-sync-manifest.yaml
kubectl wait -n config-management-system deploy/reconciler-manager --for=condition=Available --timeout=5m
```

Use `v1.22.2` to match the customer. Repeat with the latest release to confirm the behavior is unchanged.

## Repro

### 1. Sync platform-fp alone (simulates platform-fp winning the Day-0 race)

```bash
kubectl apply -f knv2006-repro/rootsyncs/platform-fp.yaml
```

Wait about a minute, then check:

```bash
# Both namespaces exist, created by platform-fp as implicit namespaces
kubectl get ns vm-workloads platform-nats -o 'custom-columns=NAME:.metadata.name,MANAGER:.metadata.annotations.configsync\.gke\.io/manager,INVENTORY:.metadata.annotations.config\.k8s\.io/owning-inventory'

# ResourceGroup/platform-fp lists both Namespaces
kubectl get resourcegroup platform-fp -n config-management-system -o jsonpath='{range .spec.resources[*]}{.kind}/{.name}{"\n"}{end}'

# KNV1021 for the Widget (CRD not installed yet). This is expected.
kubectl get rootsync platform-fp -n config-management-system -o jsonpath='{.status.source.errors}'
```

### 2. Sync cluster-fp (takes over the namespaces, installs the CRD)

```bash
kubectl apply -f knv2006-repro/rootsyncs/cluster-fp.yaml
```

### 3. Observe the deadlock

```bash
# Namespaces now report cluster-fp as manager
kubectl get ns vm-workloads platform-nats -o 'custom-columns=NAME:.metadata.name,MANAGER:.metadata.annotations.configsync\.gke\.io/manager'

kubectl get rootsync platform-fp -n config-management-system -o jsonpath='{.status.sync.errors}'
kubectl logs -n config-management-system deploy/root-reconciler-platform-fp -c reconciler | grep -E 'KNV2006|Failed to validate declared resources'
```

Expected: `KNV2006: New commit would delete all Namespaces [vm-workloads platform-nats]`, repeating on every retry. `Widget/sample` is never applied:

```bash
kubectl get widgets -n vm-workloads
```

### 4. Apply the workaround used in production

```bash
kubectl rollout restart deploy/root-reconciler-platform-fp -n config-management-system
```

Expected: KNV2006 clears and `Widget/sample` is created. Then check for leftovers in the inventory:

```bash
kubectl get resourcegroup platform-fp -n config-management-system -o jsonpath='{range .spec.resources[*]}{.kind}/{.name}{"\n"}{end}'
kubectl get rootsync platform-fp -n config-management-system -o jsonpath='{.status.sync.errors}'
```

If `Namespace/vm-workloads` or `Namespace/platform-nats` are still listed, or KNV2009 errors show up for objects in those namespaces, the restart alone isn't a clean recovery.

## Variants (start each on a fresh cluster: `kind delete cluster --name knv2006`)

### A. One namespace already exists (tests the "older GDCc" hypothesis)

Before step 1, create one namespace outside Config Sync:

```bash
kubectl create ns vm-workloads
```

Then run steps 1–3. Expected: no KNV2006. `platform-fp` only synthesizes `platform-nats` (1 namespace), and a 1 → 0 drop is allowed by the safeguard. If older GDCc releases pre-create one of these namespaces during cluster creation, that would explain why older clusters don't hit this.

### B. cluster-fp first (the "lucky" ordering)

Run step 2, wait for it to sync, then run step 1. Expected: no KNV2006.

### C. Mitigation: namespaceStrategy explicit

Use `rootsyncs/platform-fp-explicit.yaml` instead of `rootsyncs/platform-fp.yaml` in step 1. Expected: `platform-fp` reports apply errors for the missing namespaces until `cluster-fp` creates them, then converges. No KNV2006.

## Cleanup

```bash
kind delete cluster --name knv2006
```
