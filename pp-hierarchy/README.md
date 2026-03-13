# Hierarchy mode RootSync + nested RepoSync sample

This sample shows a **multi-repo** setup where:

- A `RootSync` syncs a **hierarchical** root repository from `pp-hierarchy/`
- The root repository directly manages cluster and bootstrap namespace resources
- The root repository defines one nested `RepoSync` object (`team-a`)
- The nested RepoSync syncs unstructured manifests from `pp-unstructured/team-a`

## Layout

```text
pp-hierarchy/
├── rootsync.yaml
├── cluster/
│   └── clusterrole-namespace-reader.yaml
├── namespaces/
│   ├── platform/
│   │   ├── namespace.yaml
│   │   └── configmap-platform-settings.yaml
│   ├── team-a/
│   │   ├── namespace.yaml
│   │   └── reposync.yaml
│   └── team-b/
│       └── namespace.yaml
├── system/
│   └── repo.yaml
├── root-sync-content/
│   └── ...
└── (RepoSync content moved to `pp-unstructured/`)
```

## Notes

- `cluster/`, `namespaces/`, and `system/` at the top level form the RootSync hierarchical repo.
- `root-sync-content/` is kept as an alternate copy of the same sample layout.
- `namespaces/team-a/reposync.yaml` is the only nested RepoSync kept in this sample.
- Unstructured workload resources live under `pp-unstructured/`.
- Update the Git URL/branch in `rootsync.yaml` and each `reposync.yaml` if you use a fork.
