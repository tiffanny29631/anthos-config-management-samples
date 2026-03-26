# Root hierarchical + RepoSync unstructured repro

This sample reproduces a setup where:

- RootSync source is **hierarchical** (`pp-hierarchy-repro`)
- RootSync has its own resources (`cluster/` and `namespaces/platform/`)
- A nested RepoSync in `namespaces/team-a/` is **unstructured**
- RepoSync points to a different repo folder: `pp-unstructured-repro/team-a`

## Layout

```text
pp-hierarchy-repro/
├── system/repo.yaml
├── cluster/clusterrole-namespace-reader.yaml
└── namespaces/
    ├── platform/
    │   ├── namespace.yaml
    │   └── configmap-platform-settings.yaml
    └── team-a/
        ├── namespace.yaml
        ├── reposync.yaml
        └── reposync-role-binding.yaml

pp-unstructured-repro/
└── team-a/
    ├── configmap-app.yaml
    └── serviceaccount-deployer.yaml
```

## Expected behavior in this setup

- Root reconciler manages root-owned resources in `pp-hierarchy-repro`.
- Namespace reconciler for `team-a/repo-sync` manages resources from `pp-unstructured-repro/team-a`.
