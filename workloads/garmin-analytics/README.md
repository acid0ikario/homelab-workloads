# Garmin analytics

Stack coexistente (no reemplaza `garmin-health-dashboard`) con collector + Fluent Bit dedicado, Logstash 9.4.2, Elasticsearch 9.4.2 y Kibana 9.4.2. Los saltos durables son el PVC fuente `garmin-analytics-spool`, el PVC independiente `garmin-fluent-bit-buffer`, la persistent queue `garmin-logstash-queue` y `garmin-elasticsearch`.

## Prerrequisitos y render

El nodo que ejecute Elasticsearch debe tener `vm.max_map_count >= 262144` (por ejemplo, `sudo sysctl -w vm.max_map_count=262144` y la configuración persistente equivalente del host). Compruébelo en el nodo, no sólo dentro de WSL.

Render sin mutar el clúster:

```bash
kubectl kustomize workloads/garmin-analytics >/tmp/garmin-analytics.yaml
kubectl apply --dry-run=client -f /tmp/garmin-analytics.yaml
```

Los cuatro PVC son RWO con `local-path`: quedan ligados al nodo donde se provisionan y no ofrecen failover ni almacenamiento compartido. Asegure capacidad y backup en ese nodo. Una ampliación declarativa de un PVC existente sólo funciona si el StorageClass permite expansión; si no, migre los datos a un PVC nuevo de forma controlada.

## Acceso a Kibana

El Ingress exige Basic Auth mediante el Secret `garmin-kibana-basic-auth`, deliberadamente fuera de Git. Créelo de forma imperativa en el mismo namespace (el segundo comando no imprime la contraseña):

```bash
umask 077
htpasswd -c /tmp/garmin-kibana-auth garmin-admin
kubectl -n garmin-health-dashboard create secret generic garmin-kibana-basic-auth \
  --from-file=auth=/tmp/garmin-kibana-auth
rm -f /tmp/garmin-kibana-auth
```

El hostname local continúa usando HTTP. Basic Auth sobre HTTP no cifra la credencial: úselo sólo por loopback/red local confiable y no publique el Ingress. TLS local no se declara porque este repositorio no garantiza cert-manager ni un emisor; si el clúster dispone de ambos, agregue un `Certificate`/TLS Secret generado por cert-manager (nunca una clave privada en Git), configure `spec.tls` y cambie `SERVER_PUBLICBASEURL` a HTTPS. Elasticsearch y Logstash siguen siendo Services internos sin Ingress.

## Provisioning y capacidad

El Job `garmin-provision` es un hook PostSync acotado por reintentos, timeouts de curl y `activeDeadlineSeconds`. Aplica `garmin-analytics-v1`, crea/sustituye la data view `garmin-all` e importa seis dashboards con `overwrite=true`. La semántica es aditiva: actualiza IDs incluidos, pero no borra saved objects antiguos o ajenos. Para una ejecución manual fuera de Argo CD, elimine sólo el Job terminado y aplique de nuevo su manifiesto.

Presupuesto aproximado de requests: 0.5 CPU y ~2.95 GiB RAM; límites ~4.9 GiB. Elasticsearch usa heap de 1 GiB, Logstash 384 MiB y Kibana limita Node a 640 MiB. No hay réplicas ni ILM en este clúster de un nodo.

Los tamaños (spool 2 GiB, buffer Fluent Bit 2 GiB, PQ/DLQ 2 GiB y Elasticsearch 10 GiB) son garantías finitas, no entrega infinita. Se quitó el límite de almacenamiento de Fluent Bit que podía desalojar chunks; ante una caída prolongada la contrapresión conserva datos hasta agotar disco y después el productor puede fallar. Monitorice uso, backlog y errores, y migre de forma controlada antes de ese punto. La PQ máxima de 1 GiB más DLQ de 128 MiB deja margen suficiente para checkpoints y filesystem en su PVC de 2 GiB.

La PQ crea un checkpoint cada 1024 escrituras para evitar un `fsync` por evento durante backfills. Una caída puede obligar a Fluent Bit a reenviar la ventana no confirmada; los IDs estables y las operaciones `index`/`delete` hacen ese replay idempotente, mientras spool y buffer continúan siendo durables.

## Contrato pendiente con la imagen de aplicación

La configuración consume segmentos fuente inmutables `/data/analytics/spool/garmin-v3-*.ndjson`. La imagen agrupa hasta 10 000 eventos por segmento, escribe cada lote en un nombre temporal, hace `fsync`, lo cierra y lo renombra a ese patrón; nunca vuelve a modificar un segmento visible. El prefijo de generación permite conservar segmentos anteriores sin que Fluent Bit intente abrir miles de ficheros durante un replay coordinado.

Las sondas del collector comprueban de forma segura que PID 1 existe, por lo que un backfill inicial largo no se reinicia por ausencia de checkpoint. Como mejora coordinada, la aplicación debe actualizar atómicamente `/data/analytics/state/collector.heartbeat` al inicio y durante operaciones largas; una monitorización externa puede alertar por antigüedad, sin usarla como liveness destructiva.
