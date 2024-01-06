#!/usr/bin/env bash
set -e

URL="https://raw.githubusercontent.com/minio/operator/master/helm-releases/operator-5.0.6.tgz"
ARCHIVE="operator-5.0.6.tgz"

if ! helm -n $NAMESPACE status $NAME &> /dev/null; then
    if [ ! -f $ARCHIVE ]; then
        wget $GITHUB_PROXY/$URL -O $ARCHIVE
    fi

    helm install $NAME $ARCHIVE --namespace $NAMESPACE --create-namespace
else
    echo "MinIO Operator is already installed. Skipping installation."
fi

kubectl wait --for=condition=Available deployment/minio-operator -n $NAMESPACE

echo "MinIO Operator is installed and ready."
