#!/usr/bin/env bash
# Restores the poc-demo app to the last-known-good state defined in git, by
# asking ArgoCD to sync. Run this after the demo (or after CAIPE / chatops
# has done its job) to reset for the next run.
set -euo pipefail

command -v argocd >/dev/null 2>&1 || {
  echo "argocd CLI not found; falling back to kubectl apply of the manifests." >&2
  kubectl apply -k "$(dirname "$0")/../app"
  exit 0
}

argocd app sync hello-caipe
argocd app wait hello-caipe --health --timeout 120
echo "hello-caipe synced back to git state."
