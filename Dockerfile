# Apache Kafka (KRaft, no ZooKeeper) on Red Hat UBI 8
FROM registry.access.redhat.com/ubi8/ubi:latest

ARG KAFKA_VERSION=4.0.1
ARG SCALA_VERSION=2.13

ENV KAFKA_HOME=/opt/kafka \
    KAFKA_LOG_DIR=/var/lib/kafka/data \
    PATH=/opt/kafka/bin:$PATH

# Packages + Java 17 for Kafka 4.x
RUN dnf -y update && \
    dnf -y install java-17-openjdk-headless tar gzip curl sed shadow-utils hostname && \
    dnf -y clean all && rm -rf /var/cache/dnf

# Download & unpack Kafka (try main mirror, then archive)
RUN curl -fSL "https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz" -o /tmp/kafka.tgz \
 || curl -fSL "https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz" -o /tmp/kafka.tgz; \
    mkdir -p /opt && \
    tar -xzf /tmp/kafka.tgz -C /opt && \
    ln -s /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} ${KAFKA_HOME} && \
    rm -f /tmp/kafka.tgz

# Create kafka user + dirs
RUN useradd -r -u 10001 -g root -m -d /var/lib/kafka -s /sbin/nologin kafka && \
    mkdir -p /etc/kafka "${KAFKA_LOG_DIR}" && \
    chown -R kafka:root /etc/kafka /var/lib/kafka "${KAFKA_HOME}" /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} && \
    chmod -R g+rwX /etc/kafka /var/lib/kafka

# Copy config and launcher
COPY server.properties /etc/kafka/server.properties
COPY start-kafka.sh /usr/local/bin/start-kafka.sh
RUN chmod +x /usr/local/bin/start-kafka.sh && \
    chown -R kafka:root /etc/kafka

EXPOSE 9092 9093
HEALTHCHECK --interval=15s --timeout=5s --retries=20 CMD /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 >/dev/null 2>&1 || exit 1

USER kafka
ENTRYPOINT ["/usr/local/bin/start-kafka.sh"]

