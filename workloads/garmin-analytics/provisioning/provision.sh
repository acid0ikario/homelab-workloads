#!/bin/sh
set -eu

es=http://garmin-elasticsearch:9200
kibana=http://garmin-kibana:5601
curl_common='--fail --silent --show-error --connect-timeout 3 --max-time 15'

wait_for() {
  name=$1
  url=$2
  attempts=60
  n=1
  while ! curl $curl_common "$url" >/dev/null; do
    if [ "$n" -ge "$attempts" ]; then
      echo "ERROR: $name did not become ready after $attempts attempts: $url" >&2
      return 1
    fi
    echo "waiting for $name ($n/$attempts)" >&2
    n=$((n + 1))
    sleep 5
  done
}

wait_for Elasticsearch "$es/_cluster/health?wait_for_status=yellow&timeout=10s"
curl $curl_common -X PUT -H 'Content-Type: application/json' \
  --data-binary @/provision/index-template.json "$es/_index_template/garmin-analytics-v1" >/dev/null

wait_for Kibana "$kibana/api/status"
curl $curl_common -X POST -H 'kbn-xsrf: provision' -H 'Content-Type: application/json' \
  --data '{"data_view":{"id":"garmin-all","title":"garmin-*","name":"Garmin analytics","timeFieldName":"@timestamp","allowNoIndex":true},"override":true}' \
  "$kibana/api/data_views/data_view" >/dev/null
curl $curl_common -X POST -H 'kbn-xsrf: provision' \
  -F file=@/provision/kibana-dashboards.ndjson \
  "$kibana/api/saved_objects/_import?overwrite=true" >/dev/null

echo 'Garmin Elasticsearch and Kibana provisioning completed.'
