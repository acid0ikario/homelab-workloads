# apps/

Optional folder for **per-app** ArgoCD `Application` manifests when you want each
workload managed as its own Application (finer-grained sync status in the ArgoCD UI)
instead of being swept up by the recursive `workloads/` Application.

Leave empty to let the `workloads` root Application manage everything under
`workloads/` recursively.
