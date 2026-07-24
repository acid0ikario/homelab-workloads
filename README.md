# homelab-workloads — GitOps source of truth

The **desired state** of the homelab platform. [ArgoCD](https://argo-cd.readthedocs.io/)
watches this repo and reconciles the cluster to match it — nothing is applied by hand.

Part of the [homelab](https://github.com/acid0ikario/homelab) project.

## App-of-apps layout

```
bootstrap/            # ArgoCD points here first (the "root" app)
  root-infra.yaml     #   -> Application that syncs infrastructure/
  root-observability.yaml
  root-workloads.yaml
apps/                 # (optional) per-app Application manifests
infrastructure/       # ingress-nginx, cert-manager, sealed-secrets
observability/        # kube-prometheus-stack, loki, promtail
workloads/            # your actual apps (garmindashboard)
```

ArgoCD is bootstrapped by [homelab-cluster](https://github.com/acid0ikario/homelab-cluster)
with a **root Application** pointing at `bootstrap/`. That root app creates three
child Applications (infra / observability / workloads), each of which syncs its
folder. Add a new app by dropping a manifest under `workloads/` — ArgoCD picks it up.

## How a deploy happens

1. CI in an app repo builds an image and opens a **PR here** bumping the image tag.
2. You review + merge the PR.
3. ArgoCD detects the Git change and **auto-syncs** (self-heal + prune enabled).

## Conventions

- **Helm** or **Kustomize** per component — both supported by ArgoCD.
- **sealed-secrets** for anything sensitive: commit the `SealedSecret`, never the raw `Secret`.
- Image tags are the **git SHA** of the source app (immutable, traceable).

## Add a new workload

```bash
mkdir -p workloads/myapp
# add deployment.yaml / service.yaml / kustomization.yaml (or a Helm values file)
git add . && git commit -m "feat: add myapp" && git push
# ArgoCD deploys it automatically
```

## License

MIT © acid0ikario
