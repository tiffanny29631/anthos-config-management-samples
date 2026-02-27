# Hierarchical Config Sync example

This directory is a minimal **hierarchical repo** example for Config Sync.
It includes:

- `system/repo.yaml` for repo metadata
- Namespace definitions under `namespaces/`
- Namespace-scoped ConfigMaps in each namespace directory

## Structure

```text
pp-ns-selector/
├── system/
│   └── repo.yaml
└── namespaces/
    ├── team-a/
    │   ├── namespace.yaml
    │   ├── configmap-app.yaml
    │   └── configmap-env.yaml
    └── team-b/
        ├── namespace.yaml
        └── configmap-app.yaml
```

## Notes

- The `namespace.yaml` in each folder creates that namespace.
- Other resources in the same folder are automatically applied to that namespace.
