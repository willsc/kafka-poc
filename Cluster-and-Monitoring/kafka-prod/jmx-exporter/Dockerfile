# ---------- Build stage ----------
FROM registry.access.redhat.com/ubi8/ubi:latest AS build
ARG JMX_EXPORTER_VERSION=1.5.0

RUN dnf -y update && \
    dnf -y install git java-17-openjdk-devel tar gzip findutils && \
    dnf -y clean all && rm -rf /var/cache/dnf

WORKDIR /src
RUN git clone --depth 1 --branch ${JMX_EXPORTER_VERSION} https://github.com/prometheus/jmx_exporter.git .
RUN ./mvnw -B -DskipTests package

# Pick ONLY the runnable jar (exclude javadoc/sources), prefer 'standalone'
RUN mkdir -p /out && \
    STANDALONE_JAR="$(find jmx_prometheus_standalone/target -maxdepth 1 -type f \
        -name 'jmx_prometheus_standalone-*.jar' ! -name '*-sources.jar' ! -name '*-javadoc.jar' \
        | head -n1 || true)" && \
    HTTPSERVER_JAR="$(find jmx_prometheus_httpserver/target -maxdepth 1 -type f \
        -name 'jmx_prometheus_httpserver-*.jar' ! -name '*-sources.jar' ! -name '*-javadoc.jar' \
        | head -n1 || true)" && \
    SRC_JAR="${STANDALONE_JAR:-$HTTPSERVER_JAR}" && \
    test -n "$SRC_JAR" && \
    cp "$SRC_JAR" /out/jmx_prometheus_httpserver.jar

# ---------- Runtime stage ----------
FROM registry.access.redhat.com/ubi8/ubi:latest
ENV JMX_EXPORTER_HOME=/opt/jmx \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin \
    JMX_EXPORTER_PORT=9404 \
    JMX_TARGET_HOST=localhost \
    JMX_TARGET_PORT=9999

RUN dnf -y update && \
    dnf -y install java-17-openjdk-headless curl gettext && \
    dnf -y clean all && rm -rf /var/cache/dnf

RUN mkdir -p ${JMX_EXPORTER_HOME} /run/jmx /opt/jmx/templates
COPY --from=build /out/jmx_prometheus_httpserver.jar ${JMX_EXPORTER_HOME}/jmx_prometheus_httpserver.jar
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9404
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

