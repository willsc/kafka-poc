#!/usr/bin/env bash
set -euo pipefail
: "${JMX_EXPORTER_HOME:=/opt/jmx}"
: "${JMX_EXPORTER_PORT:=9404}"
: "${JMX_TARGET_HOST:=localhost}"
: "${JMX_TARGET_PORT:=9999}"
RENDERED="/run/jmx/kafka.yml"

if [[ -n "${JMX_CONFIG:-}" && -f "${JMX_CONFIG}" ]]; then
  CFG="${JMX_CONFIG}"
elif [[ -f "/opt/jmx/templates/kafka.yml.tmpl" ]]; then
  export JMX_TARGET_HOST JMX_TARGET_PORT
  envsubst '${JMX_TARGET_HOST} ${JMX_TARGET_PORT}' \
    < /opt/jmx/templates/kafka.yml.tmpl > "${RENDERED}"
  CFG="${RENDERED}"
else
  cat > "${RENDERED}" <<EOF
startDelaySeconds: 10
lowercaseOutputName: true
lowercaseOutputLabelNames: true
hostPort: ${JMX_TARGET_HOST}:${JMX_TARGET_PORT}
rules:
  - pattern: '.*'
EOF
  CFG="${RENDERED}"
fi

echo "JMX Exporter listening :${JMX_EXPORTER_PORT} → target ${JMX_TARGET_HOST}:${JMX_TARGET_PORT} (metrics at /metrics)"
exec java ${JAVA_OPTS:-} -jar "${JMX_EXPORTER_HOME}/jmx_prometheus_httpserver.jar" "${JMX_EXPORTER_PORT}" "${CFG}"

