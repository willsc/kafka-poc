# Apache Kafka on UBI 8 (KRaft, No ZooKeeper)

This repo builds a **single-node Apache Kafka** image on **Red Hat UBI 8** and runs it in **KRaft** mode (no ZooKeeper). It's ideal for local dev, CI, and demos.

> Kafka 4.x uses KRaft by default. This image runs a **combined** node (controller + broker) and formats storage automatically on first run.

---

## Contents



---

## Quick start

```bash
# Build
docker build -t kafka:4.0.1 .

# Create a data volume (persists cluster ID & logs)
docker volume create kafka_data

# Run (Linux host)
docker run -d --name kafka \
  -p 9092:9092 -p 9093:9093 \
  -v kafka_data:/var/lib/kafka/data \
  kafka:4.0.1



docker run -d --name kafka \
  -p 9092:9092 -p 9093:9093 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://host.docker.internal:9092 \
  -v kafka_data:/var/lib/kafka/data \
  kafka:4.0.1



# Create a topic
docker exec -it kafka kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --topic demo --partitions 1 --replication-factor 1

# Produce (type lines, Ctrl+C to exit)
docker exec -it kafka kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic demo

# Consume
docker exec -it kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 --topic demo --from-beginning



version: "3.8"
services:
  kafka:
    build: .
    container_name: kafka
    ports:
      - "9092:9092"
      - "9093:9093"
    environment:
      # For Docker Desktop hosts, uncomment the next line:
      # KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://host.docker.internal:9092"
      # For Linux hosts, you might prefer:
      # KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://127.0.0.1:9092"
    volumes:
      - kafka_data:/var/lib/kafka/data
    healthcheck:
      test: [ "CMD", "/opt/kafka/bin/kafka-broker-api-versions.sh", "--bootstrap-server", "localhost:9092" ]
      interval: 15s
      timeout: 5s
      retries: 20

volumes:
  kafka_data:

**List topics

docker compose up -d --build

docker exec -it kafka kafka-topics.sh --bootstrap-server localhost:9092 --list

**Describe a topic

docker exec -it kafka kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic demo


**Delete the data / reset the cluster

# WARNING: wipes all topics and the cluster ID
docker rm -f kafka
docker volume rm kafka_data

