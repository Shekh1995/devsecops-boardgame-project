#!/usr/bin/env bash
set -euo pipefail
IMAGE="${1:?Usage: ./scripts/deploy.sh docker.io/user/boardgame:tag}"
kubectl apply -f k8s/namespace.yaml
sed "s|IMAGE_PLACEHOLDER|${IMAGE}|g" k8s/deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/service.yaml -f k8s/ingress.yaml
kubectl -n boardgame rollout status deployment/boardgame-api --timeout=180s
