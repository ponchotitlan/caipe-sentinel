#!/usr/bin/env bash
# Intentionally drifts the poc-demo deployment away from what's in git, so
# ArgoCD reports OutOfSync/Degraded and CAIPE's self-healing-gitops skill has
# something real to detect and file a GitHub issue about.
#
# Usage:
#   ./break-demo.sh all        # ImagePullBackOff, 0 replicas, and OOMKilled crash loop (default)
#   ./break-demo.sh badimage   # ImagePullBackOff
#   ./break-demo.sh scaledown  # 0 replicas
#   ./break-demo.sh oom        # memory limit too low -> OOMKilled crash loop
set -euo pipefail

MODE="${1:-all}"
NS=poc-demo
DEPLOY=hello-caipe

case "$MODE" in
  all)
    kubectl -n "$NS" set image deploy/"$DEPLOY" "$DEPLOY"=nginxdemos/hello:does-not-exist
    kubectl -n "$NS" scale deploy/"$DEPLOY" --replicas=0
    kubectl -n "$NS" patch deploy/"$DEPLOY" --type=json -p \
      '[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"16Mi"}]'
    echo "Applied bad image, scaled to 0 replicas, and dropped the memory limit to 16Mi."
    ;;
  badimage)
    kubectl -n "$NS" set image deploy/"$DEPLOY" "$DEPLOY"=nginxdemos/hello:does-not-exist
    echo "Set a nonexistent image tag -> expect ImagePullBackOff."
    ;;
  scaledown)
    kubectl -n "$NS" scale deploy/"$DEPLOY" --replicas=0
    echo "Scaled to 0 replicas -> expect Missing/Degraded workload."
    ;;
  oom)
    kubectl -n "$NS" patch deploy/"$DEPLOY" --type=json -p \
      '[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"16Mi"}]'
    echo "Dropped memory limit to 16Mi -> expect OOMKilled restarts."
    ;;
  *)
    echo "Unknown mode: $MODE (expected all|badimage|scaledown|oom)" >&2
    exit 1
    ;;
esac

echo
echo "This is a live drift from what ArgoCD has in git (selfHeal is off),"
echo "so the Application will show OutOfSync/Degraded until 'fix-demo.sh' runs."
