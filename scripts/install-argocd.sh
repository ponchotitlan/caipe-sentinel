#!/usr/bin/env bash
# Install ArgoCD into the current kube-context's "argocd" namespace using the
# official upstream manifests. Safe to re-run (kubectl apply is idempotent).
set -euo pipefail

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for argocd-server to be ready..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s

echo
echo "ArgoCD installed. Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
echo
echo "Port-forward the UI with:"
echo "  kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo "Then open https://localhost:8080 (user: admin)"
