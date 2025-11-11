# WEKA
KAFKA_STORAGE_CLASS=storageclass-wekafs-dir-api \
PROM_STORAGE_CLASS=storageclass-wekafs-dir-api \
GRAFANA_STORAGE_CLASS=storageclass-wekafs-dir-api \
envsubst < kafka-k8s-stack-with-vars.yaml | kubectl apply -f -

# Ceph (RBD)
KAFKA_STORAGE_CLASS=rook-ceph-block \
PROM_STORAGE_CLASS=rook-ceph-block \
GRAFANA_STORAGE_CLASS=rook-ceph-block \
envsubst < kafka-k8s-stack-with-vars.yaml | kubectl apply -f -

