# hello-caipe Drift Analysis Report

## Summary
The `hello-caipe` application in namespace `poc-demo` has significant drift between Git desired state and live cluster state. ArgoCD reports the application as OutOfSync with manual modifications detected: the deployment image was changed from `nginxdemos/hello:plain-text` to a non-existent image `nginxdemos/hello:does-not-exist`, replicas were scaled from 2 to 0, and memory limits were reduced from 64Mi to 16Mi. These changes occurred after ArgoCD's last successful sync at 2026-09-14 18:05:54 UTC.

## Finding
**Critical drift detected**: Manual cluster modifications have overridden GitOps desired state. The deployment is scaled to zero with a broken image reference, preventing any pods from running.

## Evidence

| Source | Observation |
|---|---|
| **ArgoCD Application** | |
| Sync Status | OutOfSync |
| Health Status | Healthy (misleading - no pods running) |
| Last Sync | 2026-09-14 18:05:54 UTC (revision 513cabd6) |
| Sync Result | "successfully synced (all tasks run)" |
| Desired Image | `nginxdemos/hello:plain-text` |
| Desired Replicas | 2 |
| Desired Memory Limit | 64Mi |
| Self-Heal | **Disabled** (automated prune enabled, selfHeal: false) |
| **Live Kubernetes Deployment** | |
| Current Image | `nginxdemos/hello:does-not-exist` ❌ |
| Current Replicas | 0 (scaled down) |
| Current Memory Limit | 16Mi |
| Ready Pods | 0/0 |
| Deployment Generation | 8 (modified 8 times) |
| Revision | 5 |
| Last Applied Config | Shows correct values (plain-text, replicas: 2, 64Mi) |
| **ReplicaSets** | |
| hello-caipe-66898cfb9b | 0/0 replicas, image: `nginxdemos/hello:plain-text` (correct) |
| hello-caipe-74654849c9 | 0/0 replicas, image: `nginxdemos/hello:does-not-exist` (broken) |
| hello-caipe-64cd9bb8f8 | 0/0 replicas, image: `nginxdemos/hello:does-not-exist` (broken) |
| **Events Timeline** | |
| 18:05:54 | ArgoCD synced deployment with correct image |
| 18:05:54 | Scaled up ReplicaSet 66898cfb9b to 2 (correct image) |
| 18:06:17 | Scaled up ReplicaSet 74654849c9 to 1 (broken image) |
| 18:06:17 | Scaled down ReplicaSet 66898cfb9b from 2 to 0 |
| 18:06:17 | Scaled down ReplicaSet 74654849c9 from 1 to 0 |
| 18:05:25 | ImagePullBackOff: "nginxdemos/hello:does-not-exist: not found" |

## Impact

**Operational Impact:**
- **Zero availability**: No pods are running (0/0 ready)
- **Service disruption**: The hello-caipe service has no backend endpoints
- **Failed deployments**: Image pull failures prevent pod creation
- **Resource waste**: Continuous failed reconciliation attempts

**GitOps Impact:**
- **Drift undetected by health checks**: ArgoCD reports "Healthy" despite zero pods
- **Manual changes persist**: Self-heal is disabled, so drift remains indefinitely
- **Configuration confusion**: Live state contradicts Git source of truth
- **Audit trail broken**: Manual changes bypass GitOps workflow

**Timeline of Failure:**
1. ArgoCD successfully synced correct configuration (18:05:54)
2. Within 23 seconds, manual intervention changed image and scaled to 0 (18:06:17)
3. Broken image caused ImagePullBackOff errors
4. Deployment was scaled to 0, hiding the image pull failures
5. ArgoCD detected OutOfSync but took no corrective action (selfHeal disabled)

## Action Taken

**No remediation action taken** - this is a read-only analysis report.

## Verification

Current state as of 2026-09-14 18:10 UTC:

| Check | Status |
|---|---|
| ArgoCD Sync Status | ❌ OutOfSync |
| Pods Running | ❌ 0/0 |
| Image Pullable | ❌ does-not-exist tag not found |
| Replicas Match Git | ❌ 0 actual vs 2 desired |
| Image Matches Git | ❌ does-not-exist vs plain-text |
| Memory Limits Match Git | ❌ 16Mi vs 64Mi |

## Follow-up

**Immediate Actions Required:**

1. **Restore desired state**: Trigger ArgoCD sync to revert manual changes
   ```bash
   argocd app sync hello-caipe --prune
   ```

2. **Enable self-heal**: Update ArgoCD application to prevent future drift
   ```yaml
   syncPolicy:
     automated:
       prune: true
       selfHeal: true  # Change from false to true
   ```

3. **Investigate root cause**: Determine who/what made the manual changes
   - Check kubectl audit logs for deployment modifications at 18:06:17 UTC
   - Review CI/CD pipelines for unauthorized kubectl commands
   - Check for rogue automation or scripts

**Preventive Measures:**

1. **Enable self-heal** on all production applications to auto-correct drift
2. **Implement RBAC restrictions** to prevent manual deployment modifications
3. **Add monitoring alerts** for OutOfSync applications
4. **Review deployment permissions** in poc-demo namespace
5. **Add admission webhooks** to block direct deployment modifications

**Open Questions:**

- Who or what modified the deployment at 18:06:17 UTC?
- Why was the image changed to a non-existent tag?
- Why was the deployment scaled to 0?
- Are there other applications with similar drift?
- Is this a test scenario or an actual incident?

**Risk Assessment:**

- **Severity**: High (complete service outage)
- **Scope**: Single application (hello-caipe)
- **Blast radius**: poc-demo namespace only
- **Recovery time**: < 1 minute (single ArgoCD sync)
- **Recurrence risk**: High (selfHeal disabled, no RBAC enforcement)

---

**Report Generated**: 2026-09-14 18:10 UTC  
**ArgoCD Application**: [hello-caipe](http://172.17.0.1:30080/applications/argocd/hello-caipe)  
**Namespace**: poc-demo  
**Git Repository**: https://github.com/ponchotitlan/caipe-sentinel.git  
**Git Revision**: 513cabd6cab4bef44885ac6ce85faeea6f349a03  
**Git Path**: app/
