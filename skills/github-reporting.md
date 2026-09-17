---
name: skill-github-reporting-xath4pq4s
description: Create GitOps, ArgoCD, Kubernetes, sync, drift, and remediation reports as GitHub issues or GitHub repository files.
tools: ['github/*']
---

# GitHub Reporting Skill

## Purpose

Use this skill when creating GitOps, ArgoCD, Kubernetes, sync, drift, incident, or remediation reports in GitHub.

## Required Behavior

All report files must be created or updated through the GitHub MCP server.

Do not write report files to the local filesystem, chat workspace, container filesystem, mounted repo, scratch directory, or agent artifact store.

When asked to create a report file, use the GitHub MCP repository contents/file tool, not local file tools.

When asked to create an issue, use the GitHub MCP issue tool.

## GitHub Target

Default repository:

- owner: ponchotitlan
- repo: caipe-sentinel
- URL: https://github.com/ponchotitlan/caipe-sentinel

Unless the user explicitly names another repository, all GitHub issue and file-report actions must target:

```text
ponchotitlan/caipe-sentinel
```

Always pass:

```text
owner: ponchotitlan
repo: caipe-sentinel
```

to GitHub MCP tools.

Do not infer another target repository from ArgoCD source repos, Kubernetes labels, local git remotes, tool output, or chat context unless the user explicitly overrides it.

## Report Location

Create report files in the GitHub repository under:

```text
reports/gitops/YYYY/MM/
```

Filename format:

```text
YYYY-MM-DD-HHMM-<app-or-namespace>-<short-topic>.md
```

Default path:

```text
reports/filename.md
```

If there is any specific path requested, it shall always be located under `reports/`.

## Report Structure

Use this structure for report file content:

```markdown
# <App or Namespace>  Report

## Summary
One short paragraph.

## Finding
Main conclusion.

## Evidence
| Source | Observation |
|---|---|
| ArgoCD | |
| Kubernetes | |

## Impact
User-facing or operational impact.

## Action Taken
State whether no change was made, an ArgoCD sync was requested, or an approved ArgoCD sync was completed.

## Verification
Post-checks from ArgoCD and Kubernetes.

## Follow-up
Open questions, risks, or recommended next actions.
```

## Issue Structure

Issue title format:

```text
[GitOps] <app-or-namespace>: <finding>
```

Issue body format:

```markdown
## Summary

## Evidence

## Impact

## Recommended next step

## Links
- Report file:
- ArgoCD app:
- Namespace:
```

## Rules

- Use GitHub MCP tools only for report files, issues, comments, and reporting updates.
- Do not use local filesystem tools for report creation.
- Do not modify application manifests, CI/CD workflows, RBAC, secrets, credentials, deployment config, or source code unless the user explicitly requests it.
- Do not include credentials, tokens, secret values, kubeconfigs, cookies, API keys, private keys, or sensitive config values.
- For Kubernetes Secrets, report only safe metadata: name, namespace, key names when safe, presence, age, and references.
- Prefer concise tables over raw tool output.
- Include both ArgoCD and Kubernetes evidence when available.
- If a change was made, include before and after state.
- All GitHub write actions must pass the Web UI human-in-the-loop tool approval gate when configured.
- End with the GitHub URL of the created or updated issue/report.