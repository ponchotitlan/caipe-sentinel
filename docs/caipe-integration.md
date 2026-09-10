# GitOps Sentinel — Stage 2: wiring in CAIPE (chatops + autonomous health checks)

> Do this after the toy app is already deployed via ArgoCD (see the main
> [README.md](../README.md)). This stage adds CAIPE: asking a chatbot about
> the app's pods, and a scheduled agent that files a GitHub issue when it
> detects drift or degraded health.

## What's in this folder

| Path | Purpose |
|---|---|
| [app/](../app/) | Toy app (`hello-caipe`) manifests, deployed via ArgoCD |
| [argocd/application.yaml](../argocd/application.yaml) | ArgoCD `Application` pointing at `app/` |
| [scripts/install-argocd.sh](../scripts/install-argocd.sh) | Installs ArgoCD into the k3s cluster |
| [scripts/break-demo.sh](../scripts/break-demo.sh) | Intentionally drifts the app (bad image / scale-down / OOM) |
| [scripts/fix-demo.sh](../scripts/fix-demo.sh) | Syncs the app back to its git state |
| [autonomous-task.json](../autonomous-task.json) | Example payload to register the scheduled health-check task |

The CAIPE skill that does the detection + issue-filing lives in the CAIPE
chart so it ships with any CAIPE deployment:
`ai-platform-engineering/charts/ai-platform-engineering/data/skills/gitops-sentinel/SKILL.md`

## Prerequisites

- A GitHub PAT with `repo` scope (issues) for the `mcp-github` agent
- An LLM API key (Anthropic/OpenAI/Bedrock) for CAIPE itself
- CAIPE deployed on the same cluster as ArgoCD (see the CAIPE repo's kind/k3s
  quickstart if not already done)

## Enable the MCP servers and autonomous agents

In `charts/ai-platform-engineering/values.yaml` (or an overlay):

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

## Register the scheduled health-check task

Easiest: in the CAIPE UI, go to **Autonomous**, create a task, pick the
dynamic agent that has ArgoCD + kubectl + GitHub tools, cron `*/30 * * * *`,
and paste the prompt from [autonomous-task.json](../autonomous-task.json).

Or via API once you have the dynamic agent id and a session token:

```bash
curl -X POST "$CAIPE_UI_URL/api/autonomous/tasks" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d @autonomous-task.json
```

For a live demo, don't wait 30 minutes — use the task's **Run now** button
in the UI right after you break things.

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
