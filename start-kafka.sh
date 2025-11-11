#!/usr/bin/env bash
set -euo pipefail

CONF=/etc/kafka/server.properties
DATA_DIR=${KAFKA_LOG_DIR:-/var/lib/kafka/data}
META_FILE="$DATA_DIR/meta.properties"

# Allow override of advertised.listeners at runtime
if [[ -n "${KAFKA_ADVERTISED_LISTENERS:-}" ]]; then
  sed -ri "s|^advertised.listeners=.*|advertised.listeners=${KAFKA_ADVERTISED_LISTENERS}|" "$CONF"
fi

# Format KRaft storage on first run
if [[ ! -f "$META_FILE" ]]; then
  CLUSTER_ID="${KAFKA_CLUSTER_ID:-$(${KAFKA_HOME}/bin/kafka-storage.sh random-uuid)}"
  echo "Formatting KRaft storage in $DATA_DIR with CLUSTER_ID=$CLUSTER_ID"
  "${KAFKA_HOME}/bin/kafka-storage.sh" format -t "$CLUSTER_ID" -c "$CONF"
fi

# Start broker+controller (single-node combined mode)
exec "${KAFKA_HOME}/bin/kafka-server-start.sh" "$CONF"

