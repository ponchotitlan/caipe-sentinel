# GitOps Sentinel — a self-healing GitOps PoC (CAIPE + Kubernetes + ArgoCD + GitHub)

**Story:** deploy a toy app via ArgoCD into a local k3s cluster -> break it
live -> a CAIPE autonomous agent detects the drift/degraded health on a
schedule and opens a GitHub issue -> you ask CAIPE about it over chatops ->
fix it and watch the app go green again.

This folder is a standalone companion to the
[ai-platform-engineering](https://github.com/cnoe-io/ai-platform-engineering)
(CAIPE) repo, expected to sit next to it on disk (`../ai-platform-engineering`).

## What's in this folder

| Path | Purpose |
|---|---|
| [app/](app/) | Toy app (`hello-caipe`) manifests, deployed via ArgoCD |
| [argocd/application.yaml](argocd/application.yaml) | ArgoCD `Application` pointing at `app/` |
| [scripts/install-argocd.sh](scripts/install-argocd.sh) | Installs ArgoCD into the k3s cluster |
| [scripts/break-demo.sh](scripts/break-demo.sh) | Intentionally drifts the app (bad image / scale-down / OOM) |
| [scripts/fix-demo.sh](scripts/fix-demo.sh) | Syncs the app back to its git state |
| [autonomous-task.json](autonomous-task.json) | Example payload to register the scheduled health-check task |

The CAIPE skill that does the detection + issue-filing lives in the CAIPE
chart so it ships with any CAIPE deployment:
`ai-platform-engineering/charts/ai-platform-engineering/data/skills/gitops-sentinel/SKILL.md`

## Prerequisites

- A running **k3s** cluster (`curl -sfL https://get.k3s.io | sh -` on the host,
  or already installed) plus `kubectl`, `helm`, and (optionally) the `argocd` CLI
- k3s writes its kubeconfig to `/etc/rancher/k3s/k3s.yaml` (root-owned). Point
  `kubectl`/`helm` at it, e.g.:
  ```bash
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  # or: sudo k3s kubectl ...
  # or copy it: sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config && chmod 600 ~/.kube/config
  ```
- A git remote you can push this folder to (its own repo, e.g.
  `gitops-sentinel`) — ArgoCD syncs from git, not your laptop
- A GitHub PAT with `repo` scope (issues) for the `mcp-github` agent
- An LLM API key (Anthropic/OpenAI/Bedrock) for CAIPE itself

## Setup

### 1. Point kubectl at k3s and install ArgoCD

```bash
cd gitops-sentinel
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes   # sanity check: your k3s node should show Ready
./scripts/install-argocd.sh
```

k3s already bundles Traefik as its ingress controller and ServiceLB as its
load balancer, so no extra port-mapping config is needed the way kind
requires it — `kubectl port-forward` (used below) or a k3s `Ingress`/
`LoadBalancer` Service both work out of the box.

### 2. Push this folder to a repo ArgoCD can reach

Push `gitops-sentinel/` to its own git remote, then edit
[argocd/application.yaml](argocd/application.yaml)'s `repoURL` to point at it.

```bash
kubectl apply -f argocd/application.yaml
kubectl -n poc-demo get pods -w   # wait for hello-caipe to go Running/Healthy
```

### 3. Deploy CAIPE onto the same cluster

Reuse the existing quickstart from the CAIPE repo. `setup-caipe.sh` detects
and uses your current kubectl context, including a k3s context, so leave off
`--create-cluster` (that flag is kind-only):

```bash
cd ../ai-platform-engineering
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
./setup-caipe.sh --non-interactive
```

Then enable in `charts/ai-platform-engineering/values.yaml` (or an overlay):

```yaml
tags:
  mcp-argocd: true
  mcp-aws: true        # provides eks_kubectl_execute for pod-level checks
  mcp-github: true
  autonomous-agents: true
  slack-bot: true       # or webex-bot: true
```

Configure the ArgoCD MCP with your in-cluster ArgoCD server address/token,
and the GitHub MCP with `GITHUB_PERSONAL_ACCESS_TOKEN`. See
`ai_platform_engineering/mcp/argocd/README.md` and
`ai_platform_engineering/mcp/github/README.md` in the CAIPE repo.

### 4. Register the scheduled health-check task

Easiest: in the CAIPE UI, go to **Autonomous**, create a task, pick the
dynamic agent that has ArgoCD + kubectl + GitHub tools, cron `*/30 * * * *`,
and paste the prompt from [autonomous-task.json](autonomous-task.json).

Or via API once you have the dynamic agent id and a session token:

```bash
curl -X POST "$CAIPE_UI_URL/api/autonomous/tasks" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d @autonomous-task.json
```

For the live demo, don't wait 30 minutes — use the task's **Run now**
button in the UI right after you break things.

## Running the demo live

1. Show the app healthy: ask the chatbot *"what's the status of the
   hello-caipe ArgoCD app?"* — expect a clean, synced/healthy answer.
2. Break it:
   ```bash
   ./scripts/break-demo.sh badimage
   ```
3. Trigger the autonomous task's **Run now** (or wait for cron). Watch a
   GitHub issue appear, labeled `gitops-sentinel`, with the pod table and
   recommended remediation.
4. Ask the chatbot the same question again — it now reports OutOfSync /
   Degraded and can reference the issue it just filed.
5. Optionally show the guardrail: ask the chatbot to *sync* the
   application and note that this is a separate, explicit action (this
   skill only detects and files issues — see the Guidelines section of
   `gitops-sentinel/SKILL.md`).
6. Reset for the next run:
   ```bash
   ./scripts/fix-demo.sh
   ```

## Cleanup

k3s is a persistent system service (not an ephemeral cluster like kind), so
tear down just the demo's resources instead of the whole cluster:

```bash
kubectl delete -f argocd/application.yaml
kubectl delete ns poc-demo
# optional: remove ArgoCD itself
kubectl delete ns argocd
```

To remove k3s entirely from the host: `/usr/local/bin/k3s-uninstall.sh`.
