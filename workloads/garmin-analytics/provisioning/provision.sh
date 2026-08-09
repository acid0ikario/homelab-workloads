#!/bin/sh
set -eu

es=http://garmin-elasticsearch:9200
kibana=http://garmin-kibana:5601

until curl --fail --silent "$es/_cluster/health?wait_for_status=yellow" >/dev/null; do sleep 5; done
curl --fail --silent --show-error -X PUT -H 'Content-Type: application/json' \
  --data-binary @/provision/index-template.json "$es/_index_template/garmin-analytics-v1" >/dev/null

until curl --fail --silent "$kibana/api/status" >/dev/null; do sleep 5; done
curl --fail --silent --show-error -X POST -H 'kbn-xsrf: provision' -H 'Content-Type: application/json' \
  --data '{"data_view":{"id":"garmin-all","title":"garmin-*","name":"Garmin analytics","timeFieldName":"@timestamp","allowNoIndex":true},"override":true}' \
  "$kibana/api/data_views/data_view" >/dev/null
curl --fail --silent --show-error -X POST -H 'kbn-xsrf: provision' \
  -F file=@/provision/kibana-dashboards.ndjson \
  "$kibana/api/saved_objects/_import?overwrite=true" >/dev/null
