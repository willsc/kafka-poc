#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------
# Config (override via environment)
# ----------------------------------
BROKERS="${BROKERS:-kafka-1:9092,kafka-2:9092,kafka-3:9092}"
TOPICS=(${TOPICS:-orders payments clicks})   # space-separated
PARTITIONS="${PARTITIONS:-12}"
REPL="${REPL:-3}"

# Producer behaviour
RECORD_SIZE="${RECORD_SIZE:-512}"         # bytes/msg
THROUGHPUT="${THROUGHPUT:-20000}"         # msgs/sec per producer (-1 = max)
BATCH_RECORDS="${BATCH_RECORDS:-2000000}" # msgs per loop
ACKS="${ACKS:-1}"                          # 1 or all
LINGER_MS="${LINGER_MS:-5}"
BATCH_SIZE="${BATCH_SIZE:-32768}"          # bytes
COMPRESSION="${COMPRESSION:-lz4}"          # none|gzip|snappy|lz4|zstd

# Which containers will run producers
PRODUCER_CONTAINERS=(${PRODUCER_CONTAINERS:-kafka-1 kafka-2 kafka-3})

# Minimal env for Kafka CLI (NO JMX / NO JAVA agent flags)
# Keep only PATH + KAFKA_HOME; java is found via PATH
MIN_ENV='env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin KAFKA_HOME=/opt/kafka'

# docker compose autodetect
if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "ERROR: docker compose or docker-compose not found." >&2
  exit 1
fi

usage() {
  cat <<EOF
Usage: $0 {start|stop|status|once}

  start   Create topics (if needed) and start continuous producers (background)
  stop    Stop all producer perf-test processes in broker containers
  status  Show producer processes running in broker containers
  once    Send a finite burst (BATCH_RECORDS per topic) and exit

Env vars:
  BROKERS=$BROKERS
  TOPICS="${TOPICS[*]}"
  PARTITIONS=$PARTITIONS  REPL=$REPL
  RECORD_SIZE=$RECORD_SIZE  THROUGHPUT=$THROUGHPUT  BATCH_RECORDS=$BATCH_RECORDS
  ACKS=$ACKS  LINGER_MS=$LINGER_MS  BATCH_SIZE=$BATCH_SIZE  COMPRESSION=$COMPRESSION
  PRODUCER_CONTAINERS="${PRODUCER_CONTAINERS[*]}"
EOF
}

create_topics() {
  echo "Creating topics (if not exist): ${TOPICS[*]}"
  $COMPOSE exec -T kafka-1 bash -lc '
    set -e
    for T in '"${TOPICS[*]}"'; do
      '"$MIN_ENV"' /opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server "'"$BROKERS"'" \
        --create --if-not-exists --topic "$T" \
        --partitions '"$PARTITIONS"' --replication-factor '"$REPL"'
    done
  '
}

# Looping producer template (filled by sed)
producer_cmd() {
  cat <<'CMDEOF'
while :; do
  /opt/kafka/bin/kafka-producer-perf-test.sh \
    --topic __TOPIC__ \
    --num-records __BATCH_RECORDS__ \
    --record-size __RECORD_SIZE__ \
    --throughput __THROUGHPUT__ \
    --producer-props \
      acks=__ACKS__ \
      linger.ms=__LINGER_MS__ \
      batch.size=__BATCH_SIZE__ \
      compression.type=__COMPRESSION__ \
      bootstrap.servers=__BROKERS__
done
CMDEOF
}

start_producers() {
  create_topics
  echo "Starting continuous producers on containers: ${PRODUCER_CONTAINERS[*]}"

  local i=0
  for t in "${TOPICS[@]}"; do
    local svc="${PRODUCER_CONTAINERS[$(( i % ${#PRODUCER_CONTAINERS[@]} ))]}"
    i=$((i+1))

    # Build command body with parameters substituted
    local body
    body="$(producer_cmd \
      | sed -e "s/__TOPIC__/$t/g" \
            -e "s/__BATCH_RECORDS__/$BATCH_RECORDS/g" \
            -e "s/__RECORD_SIZE__/$RECORD_SIZE/g" \
            -e "s/__THROUGHPUT__/$THROUGHPUT/g" \
            -e "s/__ACKS__/$ACKS/g" \
            -e "s/__LINGER_MS__/$LINGER_MS/g" \
            -e "s/__BATCH_SIZE__/$BATCH_SIZE/g" \
            -e "s/__COMPRESSION__/$COMPRESSION/g" \
            -e "s#__BROKERS__#$BROKERS#g" )"

    echo "  -> $svc producing to '$t' (background, clean env)"
    # Run with a CLEAN environment: no JMX, no JAVA_TOOL_OPTIONS, etc.
    # We also explicitly clear common Java/Kafka envs to be extra safe.
    $COMPOSE exec -T "$svc" bash -lc '
      unset JMX_PORT JMX_RMI_PORT JMX_HOSTNAME JMX_OPTS KAFKA_JMX_OPTS \
            JAVA_TOOL_OPTIONS JDK_JAVA_OPTIONS KAFKA_OPTS KAFKA_HEAP_OPTS KAFKA_JVM_PERFORMANCE_OPTS;
      nohup '"$MIN_ENV"' /bin/bash -c '"'"'$0'"'"' >/var/log/'"$t"'-perf.log 2>&1 & disown
    ' "$body"
  done

  echo "Producers started. Use '$0 status' to verify and '$0 stop' to stop."
}

stop_producers() {
  echo "Stopping producers (kafka-producer-perf-test.sh) in broker containers..."
  for svc in "${PRODUCER_CONTAINERS[@]}"; do
    echo "  -> $svc"
    $COMPOSE exec -T "$svc" bash -lc "pkill -f kafka-producer-perf-test.sh || true; sleep 1; pkill -9 -f kafka-producer-perf-test.sh || true"
  done
  echo "Done."
}

status_producers() {
  for svc in "${PRODUCER_CONTAINERS[@]}"; do
    echo "----- $svc -----"
    $COMPOSE exec -T "$svc" bash -lc "ps -ef | grep -v grep | grep kafka-producer-perf-test.sh || true"
  done
}

once_burst() {
  create_topics
  echo "Sending a finite burst ($BATCH_RECORDS records/topic) from kafka-1 (clean env)..."
  $COMPOSE exec -T kafka-1 bash -lc '
    set -e
    unset JMX_PORT JMX_RMI_PORT JMX_HOSTNAME JMX_OPTS KAFKA_JMX_OPTS \
          JAVA_TOOL_OPTIONS JDK_JAVA_OPTIONS KAFKA_OPTS KAFKA_HEAP_OPTS KAFKA_JVM_PERFORMANCE_OPTS;
    for T in '"${TOPICS[*]}"'; do
      echo " -> Producing to $T"
      '"$MIN_ENV"' /opt/kafka/bin/kafka-producer-perf-test.sh \
        --topic "$T" \
        --num-records '"$BATCH_RECORDS"' \
        --record-size '"$RECORD_SIZE"' \
        --throughput '"$THROUGHPUT"' \
        --producer-props \
          acks='"$ACKS"' \
          linger.ms='"$LINGER_MS"' \
          batch.size='"$BATCH_SIZE"' \
          compression.type='"$COMPRESSION"' \
          bootstrap.servers="'"$BROKERS"'"
    done
  '
  echo "Burst complete."
}

case "${1:-}" in
  start)  start_producers ;;
  stop)   stop_producers ;;
  status) status_producers ;;
  once)   once_burst ;;
  *)      usage; exit 1 ;;
esac

