#!/bin/bash

num_crds=100
crd_name_prefix="my-custom-resource"
namespace="my-namespace" # Replace with your desired namespace
large_field_size=10 # Adjust this to control field size

output_file="merged_crds_small.yaml"

# Create the Namespace if needed
cat <<EOF > "$output_file"
apiVersion: v1
kind: Namespace
metadata:
  name: ${namespace}
---
EOF

# Generate and merge CRDs into the output file
for (( i=1; i<=$num_crds; i++ )); do
  crd_name="${crd_name_prefix}-$i"
  large_field=$(head -c $large_field_size /dev/urandom | base64)

  cat <<EOF >> "$output_file"
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: ${crd_name}.${namespace}.example.com
spec:
  group: ${namespace}.example.com
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                largeField:
                  type: string
                  maxLength: ${large_field_size}
  scope: Namespaced
  names:
    plural: ${crd_name}s
    singular: ${crd_name}
    kind: ${crd_name}
    listKind: ${crd_name}List
---
apiVersion: ${namespace}.example.com/v1
kind: ${crd_name}
metadata:
  name: ${crd_name}-instance
  namespace: ${namespace}
spec:
  largeField: "${large_field}"
---
EOF

done
