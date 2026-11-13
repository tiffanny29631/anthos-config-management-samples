# KNV2006 repro: implicit namespace handoff between two RootSyncs

Reproduces the `RootSync/platform-fp` deadlock from b/579721612 without GDCE.

Two RootSyncs mirror the customer's Fleet Packages:

| Dir | Mirrors | Contents |
|---|---|---|
| `platform-fp/` | `platform-fp` | Objects in `vm-workloads` and `platform-nats`, no `Namespace` objects, plus a `Widget` custom resource whose CRD isn't installed yet |
| `cluster-fp/` | `cluster-fp` | `Namespace/vm-workloads`, `Namespace/platform-nats` (with `client.lifecycle.config.k8s.io/deletion: detach`, as on the customer's clusters), and the `widgets.repro.example.com` CRD |
| `cluster-fp-no-detach/` | variant D | Same as `cluster-fp/`, but the Namespaces don't declare `detach` |

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

Expected: KNV2006 clears. Check the inventory and errors right away and again after a minute or two:

```bash
kubectl get rootsync platform-fp -n config-management-system -o jsonpath='{range .status.sync.errors[*]}{.code}: {.errorMessage}{"\n"}{end}'
kubectl get resourcegroup platform-fp -n config-management-system -o jsonpath='{range .spec.resources[*]}{.kind}/{.namespace}/{.name}{"\n"}{end}'
kubectl get ns vm-workloads platform-nats -o 'custom-columns=NAME:.metadata.name,MANAGER:.metadata.annotations.configsync\.gke\.io/manager,DELETION:.metadata.annotations.client\.lifecycle\.config\.k8s\.io/deletion'
kubectl get widgets -n vm-workloads
```

Expected with `detach` on the namespaces (this setup, matching production):

1. The first sync after the restart may report KNV2009 `dependency scheduled for delete` for objects in the two namespaces. The leftover Namespace entries are in the prune set, and the `detach` annotation makes Config Sync abandon them instead of deleting them.
2. The Namespace entries disappear from `ResourceGroup/platform-fp`. The namespaces still exist and are still managed by `cluster-fp` (abandoning briefly strips Config Sync metadata, and `cluster-fp` restores it).
3. The next sync applies the ConfigMaps and `Widget/sample` with no errors.

This is why restarting the reconciler "just worked" on the customer's clusters. Compare with variant D.

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

### D. cluster-fp without detach (restart doesn't recover)

Use `rootsyncs/cluster-fp-no-detach.yaml` instead of `rootsyncs/cluster-fp.yaml` in step 2, then run steps 3 and 4. Expected after the restart:

```
KNV2009: skipped apply of ConfigMap, platform-nats/platform-config: dependency scheduled for delete: _platform-nats__Namespace
KNV2009: skipped apply of ConfigMap, vm-workloads/platform-config: dependency scheduled for delete: _vm-workloads__Namespace
KNV2009: skipped apply of Widget.repro.example.com, vm-workloads/sample: dependency scheduled for delete: _vm-workloads__Namespace
KNV2009: skipped delete of Namespace, /vm-workloads: namespace still in use: vm-workloads
KNV2009: skipped delete of Namespace, /platform-nats: namespace still in use: platform-nats
```

`cluster-fp`'s apply removes the `detach` annotation that `platform-fp` set (both apply with the same field manager). The leftover Namespace entries can't be abandoned, so the prune is skipped on every sync and stays in `ResourceGroup/platform-fp`. Only the `namespace still in use` check keeps `platform-fp` from deleting `cluster-fp`'s namespaces.

To recover, remove the two Namespace entries from the inventory:

```bash
kubectl get resourcegroup platform-fp -n config-management-system -o json \
  | jq 'del(.spec.resources[] | select(.kind=="Namespace" and (.name=="vm-workloads" or .name=="platform-nats")))' \
  | kubectl replace -f -
```

## Cleanup

```bash
kind delete cluster --name knv2006
```
