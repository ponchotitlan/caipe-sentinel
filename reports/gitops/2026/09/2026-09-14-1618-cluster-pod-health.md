# Cluster Pod Health Report

## Summary
Cluster-wide pod health check reveals a critical failure in the ArgoCD ApplicationSet controller with 837 restarts over 4 days. The controller is in CrashLoopBackOff due to a missing ApplicationSet CRD. All other pods across argocd, kube-system, and poc-demo namespaces are healthy and running normally.

## Finding
The `argocd-applicationset-controller-5959f79d67-fm75n` pod in the argocd namespace is failing continuously with exit code 1. The root cause is a missing Custom Resource Definition (CRD) for ApplicationSet in version `argoproj.io/v1alpha1`. The controller cannot start because it cannot find the required CRD to watch and reconcile ApplicationSet resources.

## Evidence

| Source | Observation |
|---|---|
| **Kubernetes Pod Status** | Pod: `argocd-applicationset-controller-5959f79d67-fm75n`<br>Status: CrashLoopBackOff<br>Restarts: 837<br>Age: 4d3h<br>Ready: 0/1<br>Exit Code: 1 |
| **Pod Logs** | Error: `failed to get restmapping: no matches for kind "ApplicationSet" in version "argoproj.io/v1alpha1"`<br>Error: `failed to wait for applicationset caches to sync`<br>Container exits after ~2 minutes of retry attempts |
| **Kubernetes Events** | Type: Warning<br>Reason: BackOff<br>Message: Back-off restarting failed container |
| **ArgoCD Version** | v3.5.2 (released 2026-08-27)<br>Image: quay.io/argoproj/argocd:v3.5.2 |
| **ArgoCD Applications** | 1 application deployed: `hello-caipe`<br>Status: Synced and Healthy<br>Project: default |
| **Healthy Pods** | argocd namespace: 6/7 pods healthy<br>kube-system: All pods running<br>poc-demo: 2/2 pods running |
| **Resource Usage** | Cluster total: 25m CPU, 288Mi memory<br>No resource pressure detected |

### Pod Breakdown by Namespace

**argocd (6/7 healthy)**
- ✅ argocd-application-controller-0: Running (1/1)
- ❌ argocd-applicationset-controller-5959f79d67-fm75n: CrashLoopBackOff (0/1)
- ✅ argocd-dex-server-6f84fd5569-6wrzv: Running (1/1)
- ✅ argocd-notifications-controller-5856884878-nxz5d: Running (1/1)
- ✅ argocd-redis-86846d5986-7qttx: Running (1/1)
- ✅ argocd-repo-server-7d44c57bc8-brxhb: Running (1/1)
- ✅ argocd-server-6f78998d5b-w25v6: Running (1/1)

**kube-system (all healthy)**
- ✅ coredns-54996dc9b4-44bqm: Running (1/1)
- ✅ local-path-provisioner-77b9867795-z74vb: Running (1/1)
- ✅ metrics-server-6dc596dfb8-rwqcg: Running (1/1)
- ✅ svclb-traefik-966fd6f3-rvl55: Running (2/2)
- ✅ traefik-59b7647586-2gt2h: Running (1/1)
- ℹ️ helm-install-traefik-c9b4w: Completed (0/1)
- ℹ️ helm-install-traefik-crd-9hsbd: Completed (0/1)

**poc-demo (all healthy)**
- ✅ hello-caipe-66898cfb9b-l8t2q: Running (1/1)
- ✅ hello-caipe-66898cfb9b-w7jkl: Running (1/1)

### Additional Warnings
- CoreDNS: Nameserver limits exceeded warning (non-critical, configuration issue)

## Impact

**Current Impact:**
- ApplicationSet functionality is completely unavailable
- Cannot create or manage ApplicationSets for multi-app deployments
- Existing Application `hello-caipe` continues to function normally
- Core ArgoCD functionality (application controller, repo server, UI) remains operational
- No impact on currently deployed workloads in poc-demo namespace

**Potential Impact:**
- Any GitOps workflows relying on ApplicationSets will fail
- Cannot use ApplicationSet generators (Git, List, Cluster, Matrix, etc.)
- Multi-cluster or multi-tenant deployments using ApplicationSets are blocked
- Continuous restart loop consumes cluster resources unnecessarily

## Action Taken

**Read-only analysis completed.** No infrastructure changes were made per agent policy.

## Verification

Not applicable - no remediation actions were executed.

## Follow-up

### Root Cause Analysis
The ApplicationSet CRD is missing from the cluster. This typically occurs when:
1. ArgoCD was upgraded but CRDs were not applied
2. CRDs were manually deleted
3. ArgoCD installation was incomplete
4. Version mismatch between ArgoCD components

### Recommended Next Steps

**Immediate (Required):**
1. **Install ApplicationSet CRD** - Apply the missing CRD for ArgoCD v3.5.2:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/crds/applicationset-crd.yaml
   ```
   Or if using the full install manifest:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/install.yaml
   ```

2. **Verify CRD installation:**
   ```bash
   kubectl get crd applicationsets.argoproj.io
   ```

3. **Monitor pod recovery:**
   ```bash
   kubectl get pods -n argocd -w
   ```
   Expected: Pod should restart successfully and reach Running (1/1) state

**Verification Steps:**
1. Check pod logs show successful startup without CRD errors
2. Verify ApplicationSet controller is ready: `kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller`
3. Test ApplicationSet functionality by creating a test ApplicationSet resource

**Risk Assessment:**
- **Risk Level:** Low - CRD installation is a safe, additive operation
- **Rollback:** CRD can be removed if needed, but should not affect existing Applications
- **Downtime:** None - operation is non-disruptive to running workloads

**Long-term:**
- Review ArgoCD installation/upgrade procedures to ensure CRDs are always applied
- Consider using ArgoCD's official Helm chart or operator for managed installations
- Implement monitoring/alerting for CrashLoopBackOff pods
- Document CRD management in GitOps runbooks

---

**Report Generated:** 2026-09-14 16:18 UTC  
**Cluster:** poncho-caipe  
**ArgoCD Version:** v3.5.2  
**Total Pods Checked:** 16  
**Healthy Pods:** 14  
**Failed Pods:** 1  
**Completed Jobs:** 2
