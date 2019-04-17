kubectl delete pv -n onap dev-dcae-db-data0 dev-dcae-db-data1 dev-dcae-redis0 dev-dcae-redis1 dev-dcae-redis2 dev-dcae-redis3 dev-dcae-redis4 dev-dcae-redis5 dev-dcae-redis6 dev-dcae-redis7 dev-dcae-redis8 dev-dcae-redis9
kubectl -n onap delete services dcae-cloudify-manager dcae-pg-primary dcae-pg-replica dcae-postgres dcae-tca-analytics  dcae-ves-collector xdcae-tca-analytics xdcae-ves-collector
kubectl -n onap delete configmaps dcae-filebeat-configmap dev-dcae-bootstrap-dcae-config dev-dcae-bootstrap-dcae-inputs dev-dcae-cloudify-manager-configmap dev-dcae-redis dev-dcae-redis-scripts
kubectl -n onap delete secrets dcae-token dev-dcae-db dcae-bootstrap-cmpass
kubectl -n onap delete statefulsets dev-dcae-redis
kubectl -n onap delete deployments dep-config-binding-service dep-dcae-tca-analytics dep-dcae-ves-collector dep-deployment-handler dep-holmes-engine-mgmt dep-holmes-rule-mgmt dep-inventory dep-policy-handler dep-pstg-write dep-service-change-handler
