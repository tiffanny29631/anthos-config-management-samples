# OSS Config Sync mixed-scope example

This directory is an **OSS Config Sync** example with:

- shared configs that install on **all clusters**
- cluster-specific configs for a **single cluster**

It avoids `cluster-name-selector` annotations and uses `RootSync.spec.git.dir`
paths instead.

## Structure

```text
pp-ns-selector/
├── all-clusters/
│   └── namespaces/
│       └── team-b/
│           ├── namespace.yaml
│           └── configmap-app.yaml
└── clusters/
    └── cstest-manual/
        └── namespaces/
            └── team-a/
                ├── namespace.yaml
                ├── configmap-app.yaml
                └── configmap-env.yaml
```

## How to use

- Create one RootSync on **every cluster** for shared configs:
  - `spec.git.dir: pp-ns-selector/all-clusters`
- Create a second RootSync only on `cstest-manual` for cluster-specific configs:
  - `spec.git.dir: pp-ns-selector/clusters/cstest-manual`

With this setup:

- `team-b` installs on all clusters
- `team-a` installs only on `cstest-manual`
