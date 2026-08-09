# Garmin analytics

Stack coexistente (no reemplaza `garmin-health-dashboard`) con collector + Fluent Bit dedicado, Logstash 9.4.2, Elasticsearch 9.4.2 y Kibana 9.4.2. Los tres saltos durables son el PVC `garmin-analytics-spool`, la persistent queue `garmin-logstash-queue` y `garmin-elasticsearch`.

Render sin mutar el clúster:

```bash
kubectl kustomize workloads/garmin-analytics >/tmp/garmin-analytics.yaml
kubectl apply --dry-run=client -f /tmp/garmin-analytics.yaml
```

El Job `garmin-provision` es un hook PostSync idempotente: aplica `garmin-analytics-v1`, crea/sustituye la data view `garmin-all` e importa seis dashboards con `overwrite=true`. Para una ejecución manual fuera de Argo CD, elimine sólo el Job terminado y aplique de nuevo su manifiesto.

Presupuesto aproximado de requests: 0.5 CPU y ~2.95 GiB RAM; límites ~4.9 GiB. Elasticsearch usa heap de 1 GiB, Logstash 384 MiB y Kibana limita Node a 640 MiB. No hay réplicas ni ILM en este clúster de un nodo.
