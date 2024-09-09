#!/usr/bin/env bash
set -e

if [[ -z "${DOMAIN}" ]]; then
    echo "Error: DOMAIN is not set or is empty. Exiting script."
    exit 1
fi

ADMIN_SECRET="object-storage-user-0"
INTERNAL_ENDPOINT="object-storage.${BACKEND_NAMESPACE}.svc.cluster.local"
EXTERNAL_ENDPOINT="objectstorageapi.${DOMAIN}"


# backend controller
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  labels:
    app.kubernetes.io/component: manager
    app.kubernetes.io/created-by: objectstorage
    app.kubernetes.io/instance: system
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: namespace
    app.kubernetes.io/part-of: objectstorage
    control-plane: controller-manager
  name: ${BACKEND_NAMESPACE}
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  annotations:
    controller-gen.kubebuilder.io/version: v0.8.0
  creationTimestamp: null
  name: objectstoragebuckets.objectstorage.sealos.io
spec:
  group: objectstorage.sealos.io
  names:
    kind: ObjectStorageBucket
    listKind: ObjectStorageBucketList
    plural: objectstoragebuckets
    singular: objectstoragebucket
  scope: Namespaced
  versions:
    - name: v1
      schema:
        openAPIV3Schema:
          description: ObjectStorageBucket is the Schema for the objectstoragebuckets
            API
          properties:
            apiVersion:
              description: 'APIVersion defines the versioned schema of this representation
              of an object. Servers should convert recognized schemas to the latest
              internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
              type: string
            kind:
              description: 'Kind is a string value representing the REST resource this
              object represents. Servers may infer this from the endpoint the client
              submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
              type: string
            metadata:
              type: object
            spec:
              description: ObjectStorageBucketSpec defines the desired state of ObjectStorageBucket
              properties:
                policy:
                  default: private
                  enum:
                    - private
                    - publicRead
                    - publicReadwrite
                  type: string
              type: object
            status:
              description: ObjectStorageBucketStatus defines the observed state of ObjectStorageBucket
              properties:
                name:
                  type: string
                size:
                  format: int64
                  type: integer
              type: object
          type: object
      served: true
      storage: true
      subresources:
        status: { }
status:
  acceptedNames:
    kind: ""
    plural: ""
  conditions: [ ]
  storedVersions: [ ]
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  annotations:
    controller-gen.kubebuilder.io/version: v0.8.0
  creationTimestamp: null
  name: objectstorageusers.objectstorage.sealos.io
spec:
  group: objectstorage.sealos.io
  names:
    kind: ObjectStorageUser
    listKind: ObjectStorageUserList
    plural: objectstorageusers
    singular: objectstorageuser
  scope: Namespaced
  versions:
    - name: v1
      schema:
        openAPIV3Schema:
          description: ObjectStorageUser is the Schema for the objectstorageusers API
          properties:
            apiVersion:
              description: 'APIVersion defines the versioned schema of this representation
              of an object. Servers should convert recognized schemas to the latest
              internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
              type: string
            kind:
              description: 'Kind is a string value representing the REST resource this
              object represents. Servers may infer this from the endpoint the client
              submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
              type: string
            metadata:
              type: object
            spec:
              description: ObjectStorageUserSpec defines the desired state of ObjectStorageUser
              type: object
            status:
              description: ObjectStorageUserStatus defines the observed state of ObjectStorageUser
              properties:
                accessKey:
                  type: string
                external:
                  type: string
                internal:
                  type: string
                objectsCount:
                  format: int64
                  type: integer
                quota:
                  format: int64
                  type: integer
                secretKey:
                  type: string
                size:
                  description: unit is byte
                  format: int64
                  type: integer
              type: object
          type: object
      served: true
      storage: true
      subresources:
        status: { }
status:
  acceptedNames:
    kind: ""
    plural: ""
  conditions: [ ]
  storedVersions: [ ]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kuberentes.io/instance: controller-manager
    app.kubernetes.io/component: rbac
    app.kubernetes.io/created-by: objectstorage
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: serviceaccount
    app.kubernetes.io/part-of: objectstorage
  name: objectstorage-controller-manager
  namespace: ${BACKEND_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/component: rbac
    app.kubernetes.io/created-by: objectstorage
    app.kubernetes.io/instance: leader-election-role
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: role
    app.kubernetes.io/part-of: objectstorage
  name: objectstorage-leader-election-role
  namespace: ${BACKEND_NAMESPACE}
rules:
  - apiGroups:
      - ""
    resources:
      - configmaps
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete
  - apiGroups:
      - coordination.k8s.io
    resources:
      - leases
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete
  - apiGroups:
      - ""
    resources:
      - events
    verbs:
      - create
      - patch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: null
  name: objectstorage-manager-role
rules:
  - apiGroups:
      - ""
    resources:
      - secrets
    verbs:
      - create
      - delete
      - get
      - list
      - patch
      - update
      - watch
  - apiGroups:
      - objectstorage.sealos.io
    resources:
      - objectstoragebuckets
    verbs:
      - create
      - delete
      - deletecollection
      - get
      - list
      - patch
      - update
      - watch
  - apiGroups:
      - objectstorage.sealos.io
    resources:
      - objectstoragebuckets/finalizers
    verbs:
      - update
  - apiGroups:
      - objectstorage.sealos.io
    resources:
      - objectstoragebuckets/status
    verbs:
      - get
      - patch
      - update
  - apiGroups:
      - objectstorage.sealos.io
    resources:
      - objectstorageusers
    verbs:
      - create
      - delete
      - get
      - list
      - patch
      - update
      - watch
  - apiGroups:
      - objectstorage.sealos.io
    resources:
      - objectstorageusers/finalizers
    verbs:
      - update
  - apiGroups:
      - objectstorage.sealos.io
    resources:
      - objectstorageusers/status
    verbs:
      - get
      - patch
      - update
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/component: kube-rbac-proxy
    app.kubernetes.io/created-by: objectstorage
    app.kubernetes.io/instance: metrics-reader
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: clusterrole
    app.kubernetes.io/part-of: objectstorage
  name: objectstorage-metrics-reader
rules:
  - nonResourceURLs:
      - /metrics
    verbs:
      - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/component: kube-rbac-proxy
    app.kubernetes.io/created-by: objectstorage
    app.kubernetes.io/instance: proxy-role
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: clusterrole
    app.kubernetes.io/part-of: objectstorage
  name: objectstorage-proxy-role
rules:
  - apiGroups:
      - authentication.k8s.io
    resources:
      - tokenreviews
    verbs:
      - create
  - apiGroups:
      - authorization.k8s.io
    resources:
      - subjectaccessreviews
    verbs:
      - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app.kubernetes.io/component: rbac
    app.kubernetes.io/created-by: objectstorage
    app.kubernetes.io/instance: leader-election-rolebinding
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: rolebinding
    app.kubernetes.io/part-of: objectstorage
  name: objectstorage-leader-election-rolebinding
  namespace: ${BACKEND_NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: objectstorage-leader-election-role
subjects:
  - kind: ServiceAccount
    name: objectstorage-controller-manager
    namespace: ${BACKEND_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/component: rbac
    app.kubernetes.io/created-by: objectstorage
    app.kubernetes.io/instance: manager-rolebinding
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: clusterrolebinding
    app.kubernetes.io/part-of: objectstorage
  name: objectstorage-manager-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: objectstorage-manager-role
subjects:
  - kind: ServiceAccount
    name: objectstorage-controller-manager
    namespace: ${BACKEND_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/component: kube-rbac-proxy
    app.kubernetes.io/created-by: objectstorage
    app.kubernetes.io/instance: proxy-rolebinding
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: clusterrolebinding
    app.kubernetes.io/part-of: objectstorage
  name: objectstorage-proxy-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: objectstorage-proxy-role
subjects:
  - kind: ServiceAccount
    name: objectstorage-controller-manager
    namespace: ${BACKEND_NAMESPACE}
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: kube-rbac-proxy
    app.kubernetes.io/created-by: objectstorage
    app.kubernetes.io/instance: controller-manager-metrics-service
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: service
    app.kubernetes.io/part-of: objectstorage
    control-plane: controller-manager
  name: objectstorage-controller-manager-metrics-service
  namespace: ${BACKEND_NAMESPACE}
spec:
  ports:
    - name: https
      port: 8443
      protocol: TCP
      targetPort: https
  selector:
    control-plane: controller-manager
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: manager
    app.kubernetes.io/created-by: objectstorage
    app.kubernetes.io/instance: controller-manager
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: deployment
    app.kubernetes.io/part-of: objectstorage
    control-plane: controller-manager
  name: objectstorage-controller-manager
  namespace: ${BACKEND_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      control-plane: controller-manager
  template:
    metadata:
      annotations:
        kubectl.kubernetes.io/default-container: manager
      labels:
        control-plane: controller-manager
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/arch
                    operator: In
                    values:
                      - amd64
                      - arm64
                      - ppc64le
                      - s390x
                  - key: kubernetes.io/os
                    operator: In
                    values:
                      - linux
      containers:
        - args:
            - --secure-listen-address=0.0.0.0:8443
            - --upstream=http://127.0.0.1:8080/
            - --logtostderr=true
            - --v=0
          image: gcr.io/kubebuilder/kube-rbac-proxy:v0.13.0
          name: kube-rbac-proxy
          ports:
            - containerPort: 8443
              name: https
              protocol: TCP
          resources:
            limits:
              cpu: 500m
              memory: 128Mi
            requests:
              cpu: 5m
              memory: 64Mi
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
        - args:
            - --health-probe-bind-address=:8081
            - --metrics-bind-address=127.0.0.1:8080
            - --leader-elect
          command:
            - /manager
          env:
            - name: OSNamespace
              value: ${BACKEND_NAMESPACE}
            - name: OSAdminSecret
              value: ${ADMIN_SECRET}
            - name: OSInternalEndpoint
              value: ${INTERNAL_ENDPOINT}
            - name: OSExternalEndpoint
              value: ${EXTERNAL_ENDPOINT}
            - name: OSUDetectionCycleSeconds
              value: "300"
            - name: MinioBucketDetectionCycleSeconds
              value: "300"
          image: ghcr.io/gclm/sealos-objectstorage-controller:latest
          imagePullPolicy: Always
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8081
            initialDelaySeconds: 15
            periodSeconds: 20
          name: manager
          readinessProbe:
            httpGet:
              path: /readyz
              port: 8081
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 5m
              memory: 64Mi
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            runAsNonRoot: true
      securityContext:
        runAsNonRoot: true
      serviceAccountName: objectstorage-controller-manager
      terminationGracePeriodSeconds: 10
EOF
