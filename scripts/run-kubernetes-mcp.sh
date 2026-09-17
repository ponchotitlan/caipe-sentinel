#!/usr/bin/env bash
# Run the official Kubernetes MCP server as a standalone Docker container.
#
# The container is deliberately not deployed as a Kubernetes workload. It
# connects to k3s through a dedicated ServiceAccount kubeconfig and joins the
# existing CAIPE Docker network so CAIPE can resolve it as kubernetes-mcp.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/run-kubernetes-mcp.sh [K3S_NODE_IP]

Create a read-only Kubernetes identity, build its kubeconfig from a
non-expiring ServiceAccount token, and run the Kubernetes MCP server in
Docker.

Environment:
  CAIPE_NETWORK  Docker network used by CAIPE
                 (default: ai-platform-engineering_default)

Examples:
  ./scripts/run-kubernetes-mcp.sh
  ./scripts/run-kubernetes-mcp.sh 192.0.2.10

Endpoints after startup:
  CAIPE: http://kubernetes-mcp:8080/mcp
  Host:  http://localhost:18004/mcp
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
image="ghcr.io/containers/kubernetes-mcp-server:v0.0.66"
container_name="kubernetes-mcp"
network_name="${CAIPE_NETWORK:-ai-platform-engineering_default}"
kubeconfig_path="$repo_root/secrets/kubernetes-mcp.kubeconfig"
config_path="$repo_root/deploy/kubernetes-mcp/config.toml"

if ! command -v kubectl >/dev/null || ! command -v docker >/dev/null; then
  echo "Error: kubectl and docker are required" >&2
  exit 1
fi

# Docker cannot reach a Kubernetes API advertised as 127.0.0.1. Prefer an
# IPv4 node InternalIP because it works reliably across Docker bridge setups.
# Allow an explicit address for remote Docker hosts or IPv6-only clusters.
if [[ -n "${1:-}" ]]; then
  node_ip="$1"
else
  node_ips=$(kubectl get nodes -o jsonpath='{range .items[0].status.addresses[?(@.type=="InternalIP")]}{.address}{"\n"}{end}')
  node_ip=$(printf '%s\n' "$node_ips" | awk '/^[0-9]+([.][0-9]+){3}$/ { print; exit }')
  node_ip="${node_ip:-$(printf '%s\n' "$node_ips" | head -n 1)}"
fi
if [[ -z "$node_ip" ]]; then
  echo "Error: no k3s node IP found; run '$0 <k3s-node-ip>'" >&2
  exit 1
fi

# Create or reconcile the namespace, ServiceAccount, and view-only binding.
kubectl apply -f "$repo_root/deploy/k8s-mcp-rbac.yaml"
mkdir -p "$repo_root/secrets"

# Build a self-contained kubeconfig.
ca_file=$(mktemp)
trap 'rm -f "$ca_file"' EXIT
kubectl config view --raw --minify \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' \
  | base64 -d > "$ca_file"

# Read the permanent token from its Secret rather than minting a new
# TokenRequest token, so the MCP server's credential never expires.
# The controller can take a few seconds to populate .data.token on a fresh Secret.
token=""
for _ in $(seq 1 10); do
  token=$(kubectl -n mcp get secret mcp-viewer-token -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || true)
  [[ -n "$token" ]] && break
  sleep 1
done
if [[ -z "$token" ]]; then
  echo "Error: mcp-viewer-token Secret has no token yet; rerun this script" >&2
  exit 1
fi
kubectl config --kubeconfig="$kubeconfig_path" set-cluster k3s \
  --server="https://$node_ip:6443" \
  --certificate-authority="$ca_file" --embed-certs=true >/dev/null
kubectl config --kubeconfig="$kubeconfig_path" set-credentials mcp-viewer \
  --token="$token" >/dev/null
kubectl config --kubeconfig="$kubeconfig_path" set-context mcp-viewer \
  --cluster=k3s --user=mcp-viewer >/dev/null
kubectl config --kubeconfig="$kubeconfig_path" use-context mcp-viewer >/dev/null
# The image runs as UID 65532. The file contains a temporary token and is only
# mounted read-only into the container, so it must be readable by that UID.
chmod 644 "$kubeconfig_path"

# Verify the credential before starting Docker, then require CAIPE's network.
kubectl --kubeconfig="$kubeconfig_path" get pods -A >/dev/null
docker network inspect "$network_name" >/dev/null

# Replace any previous instance so rerunning the script renews the token and
# applies configuration changes. The image is pinned for repeatable demos.
docker rm -f "$container_name" >/dev/null 2>&1 || true

docker run -d \
  --name "$container_name" \
  --restart unless-stopped \
  --network "$network_name" \
  -p 18004:8080 \
  --read-only \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  -v "$config_path:/etc/kubernetes-mcp/config.toml:ro" \
  -v "$kubeconfig_path:/etc/kubernetes-mcp/kubeconfig:ro" \
  "$image" \
  --config /etc/kubernetes-mcp/config.toml \
  --kubeconfig /etc/kubernetes-mcp/kubeconfig \
  --cluster-provider kubeconfig

echo "Kubernetes MCP is running as $container_name"
echo "CAIPE endpoint: http://$container_name:8080/mcp"
echo "Host test endpoint: http://localhost:18004/mcp"
echo "Token: permanent (mcp-viewer-token Secret) - no rotation needed"