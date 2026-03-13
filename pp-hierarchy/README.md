# Hierarchy mode RootSync + RepoSync sample

This sample shows a **multi-repo** setup where:

- A `RootSync` syncs a **hierarchical** root repository from `pp-hierarchy/root-sync-content/`
- The root repository directly manages cluster and bootstrap namespace resources
- The root repository also defines two `RepoSync` objects (`team-a` and `team-b`)
- Each `RepoSync` syncs an unstructured namespace repository with its own resources

## Layout

```text
pp-hierarchy/
├── rootsync.yaml
├── root-sync-content/
│   ├── cluster/
│   │   └── clusterrole-namespace-reader.yaml
│   ├── namespaces/
│   │   ├── platform/
│   │   │   ├── namespace.yaml
│   │   │   └── configmap-platform-settings.yaml
│   │   ├── team-a/
│   │   │   ├── namespace.yaml
│   │   │   └── reposync.yaml
│   │   └── team-b/
│   │       ├── namespace.yaml
│   │       └── reposync.yaml
│   └── system/
│       └── repo.yaml
└── reposync-content/
    ├── team-a/
    │   ├── configmap-app.yaml
    │   └── serviceaccount-deployer.yaml
    └── team-b/
        ├── configmap-app.yaml
        └── role-pod-reader.yaml
```

## Notes

- `root-sync-content/` is what RootSync points to and must keep hierarchical repo structure (`cluster/`, `namespaces/`, `system/`).
- `reposync-content/team-a/` and `reposync-content/team-b/` are synced by namespace-level RepoSync objects.
- Update the Git URL/branch in `rootsync.yaml` and each `reposync.yaml` if you use a fork.
