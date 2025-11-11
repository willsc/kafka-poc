#!/usr/bin/env bash
set -euo pipefail

BASE="kafka-prod"

# Create directories
mkdir -p "$BASE"/jmx-exporter \
         "$BASE"/prometheus \
         "$BASE"/grafana/provisioning/datasources \
         "$BASE"/grafana/provisioning/dashboards \
         "$BASE"/grafana/dashboards \
         "$BASE"/config

# Create empty files
touch "$BASE"/docker-compose.yml \
      "$BASE"/jmx-exporter/Dockerfile \
      "$BASE"/jmx-exporter/kafka.yml \
      "$BASE"/prometheus/prometheus.yml \
      "$BASE"/grafana/provisioning/datasources/datasource.yml \
      "$BASE"/grafana/provisioning/dashboards/dashboards.yml \
      "$BASE"/grafana/dashboards/kafka-overview.json \
      "$BASE"/grafana/dashboards/kafka-broker.json \
      "$BASE"/grafana/dashboards/jvm.json \
      "$BASE"/config/kafka-1.properties \
      "$BASE"/config/kafka-2.properties \
      "$BASE"/config/kafka-3.properties

echo "Created structure under ./$BASE"

