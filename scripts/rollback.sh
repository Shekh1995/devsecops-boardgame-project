#!/usr/bin/env bash
set -euo pipefail
kubectl -n boardgame rollout undo deployment/boardgame-api
kubectl -n boardgame rollout status deployment/boardgame-api --timeout=180s
