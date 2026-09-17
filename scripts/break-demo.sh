#!/usr/bin/env bash
# Intentionally drifts the poc-demo deployment away from what's in git, so
# ArgoCD reports OutOfSync/Degraded and CAIPE's self-healing-gitops skill has
# something real to detect and file a GitHub issue about.
#
# Usage:
#   ./break-demo.sh all        # bad image + 0 replicas + OOM-inducing startup command drift (default)
#   ./break-demo.sh badimage   # ImagePullBackOff
#   ./break-demo.sh scaledown  # 0 replicas
#   ./break-demo.sh oom        # force OOMKilled crash loop
set -euo pipefail

MODE="${1:-all}"
NS=poc-demo
DEPLOY=hello-caipe

apply_oom_patch() {
  kubectl -n "$NS" patch deploy/"$DEPLOY" --type strategic -p "$(cat <<EOF
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "$DEPLOY",
            "resources": {
              "requests": {
                "memory": "8Mi"
              },
              "limits": {
                "memory": "12Mi"
              }
            },
            "command": ["/bin/sh", "-c"],
            "args": ["dd if=/dev/zero of=/dev/shm/pedro-oom bs=1M count=128; nginx -g 'daemon off;'"]
          }
        ]
      }
    }
  }
}
EOF
)"
}

case "$MODE" in
  all)
    kubectl -n "$NS" set image deploy/"$DEPLOY" "$DEPLOY"=nginxdemos/hello:does-not-exist
    kubectl -n "$NS" scale deploy/"$DEPLOY" --replicas=0
    apply_oom_patch
    echo "Applied bad image, scaled to 0 replicas, and injected an OOM-inducing startup command with 12Mi memory limit."
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
    apply_oom_patch
    echo "Injected memory-stress startup command with a 12Mi memory limit -> expect OOMKilled restarts."
    ;;
  *)
    echo "Unknown mode: $MODE (expected all|badimage|scaledown|oom)" >&2
    exit 1
    ;;
esac

echo
echo "This is a live drift from what ArgoCD has in git (selfHeal is off),"
echo "so the Application will show OutOfSync/Degraded until ArgoCD syncs or you run: kubectl apply -k app"
