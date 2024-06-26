#!/usr/bin/env bash
set -e

if [[ -z "$DOMAIN" ]]; then
    echo "Error: DOMAIN is empty. Exiting script."
    exit 1
fi

MINIO_CONFIG_ENV=$(kubectl -n ${BACKEND_NAMESPACE} get secret object-storage-env-configuration -o jsonpath="{.data.config\.env}" | base64 --decode)
MINIO_ROOT_USER=$(echo "$MINIO_CONFIG_ENV" | tr ' ' '\n' | grep '^MINIO_ROOT_USER=' | cut -d '=' -f 2); MINIO_ROOT_USER=${MINIO_ROOT_USER//\"}
MINIO_ROOT_PASSWORD=$(echo "$MINIO_CONFIG_ENV" | tr ' ' '\n' | grep '^MINIO_ROOT_PASSWORD=' | cut -d '=' -f 2); MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD//\"}

# 生成 token
SYMMETRIC_KEY=$MINIO_ROOT_PASSWORD; HEADER='{"alg":"HS256","typ":"JWT"}'; PAYLOAD='{"exp":4833872336,"iss":"prometheus","sub":"'"$MINIO_ROOT_USER"'"}'

BASE64_HEADER=$(echo -n "$HEADER" | base64 | tr -d '\n=' | tr '/+' '_-'); BASE64_PAYLOAD=$(echo -n "$PAYLOAD" | base64 | tr -d '\n=' | tr '/+' '_-')

BASE64_SIGNATURE=$(echo -n "$BASE64_HEADER.$BASE64_PAYLOAD" | openssl dgst -binary -sha256 -hmac "$SYMMETRIC_KEY" | base64 | tr -d '\n=' | tr '/+' '_-')

TOKEN="$BASE64_HEADER.$BASE64_PAYLOAD.$BASE64_SIGNATURE"

BASE64_TOKEN=$(echo -n "$TOKEN" | base64 -w 0)

cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  labels:
    namespace: ${BACKEND_NAMESPACE}
    release: prometheus
  name: object-storage
  namespace: ${BACKEND_NAMESPACE}
spec:
  jobName: object-storage-job
  bearerTokenSecret:
    name: object-storage-probe
    key: token
  prober:
    path: /minio/v2/metrics/bucket
    scheme: http
    url: object-storage.${BACKEND_NAMESPACE}.svc.cluster.local:80
  targets:
    staticConfig:
      static:
        - object-storage.${BACKEND_NAMESPACE}.svc.cluster.local:80
---
apiVersion: v1
kind: Secret
metadata:
  name: object-storage-probe
  namespace: ${BACKEND_NAMESPACE}
data:
  token: >-
    ${BASE64_TOKEN}
type: Opaque
---
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app: object-storage-monitor
  name: object-storage-monitor-config
  namespace: ${BACKEND_NAMESPACE}
data:
  config.yml: |
    server:
      addr: ":9090"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: object-storage-monitor
  name: object-storage-monitor-deployment
  namespace: ${BACKEND_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: object-storage-monitor
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: object-storage-monitor
    spec:
      containers:
      - args:
        - /config/config.yml
        command:
        - /manager
        env:
        - name: OBJECT_STORAGE_INSTANCE
          value: object-storage.${BACKEND_NAMESPACE}.svc.cluster.local:80
        - name: PROMETHEUS_SERVICE_HOST
          value: http://prometheus-object-storage.${BACKEND_NAMESPACE}.svc.cluster.local:9090
        image: docker.io/nowinkey/sealos-database-service:v1.2.0
        imagePullPolicy: Always
        name: object-storage-monitor
        ports:
        - containerPort: 9090
          protocol: TCP
        resources:
          requests:
            cpu: 1m
            memory: 500M
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          runAsNonRoot: true
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /config
          name: config-vol
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      volumes:
      - configMap:
          defaultMode: 420
          name: object-storage-monitor-config
        name: config-vol
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: object-storage-monitor
  name: object-storage-monitor
  namespace: ${BACKEND_NAMESPACE}
spec:
  ports:
    - name: http
      port: 9090
      protocol: TCP
      targetPort: 9090
  selector:
    app: object-storage-monitor
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: object-storage-monitor
  namespace: ${BACKEND_NAMESPACE}
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: HTTP
    nginx.ingress.kubernetes.io/client-body-buffer-size: 64k
    nginx.ingress.kubernetes.io/configuration-snippet: |
      if (\$request_uri ~* \.(js|css|gif|jpe?g|png)) {
        expires 30d;
        add_header Cache-Control "public";
      }
    nginx.ingress.kubernetes.io/proxy-body-size: 1g
    nginx.ingress.kubernetes.io/proxy-buffer-size: 64k
    nginx.ingress.kubernetes.io/rewrite-target: /\$2
    nginx.ingress.kubernetes.io/server-snippet: |
      client_header_buffer_size 64k;
      large_client_header_buffers 4 128k;
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
    nginx.ingress.kubernetes.io/use-regex: 'true'
spec:
  tls:
    - hosts:
        - object-storage-monitor.${DOMAIN}
      secretName: wildcard-cert
  rules:
    - host: object-storage-monitor.${DOMAIN}
      http:
        paths:
          - path: /()(.*)
            pathType: Prefix
            backend:
              service:
                name: object-storage-monitor
                port:
                  number: 9090
EOF