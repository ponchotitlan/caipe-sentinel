# Cluster Pod Health Report

## Summary
Cluster-wide pod health assessment reveals a critical failure in the ArgoCD ApplicationSet controller due to missing CRD, while all other pods including the managed application (hello-caipe) are healthy and operational. The ApplicationSet controller has been in CrashLoopBackOff for 4 days with 824 restart attempts.

## Finding
**Critical**: ArgoCD ApplicationSet controller is failing to start due to missing ApplicationSet CRD (argoproj.io/v1alpha1). All other cluster pods are healthy.

## Evidence

| Source | Observation |
|---|---|
| **Kubernetes Pods** | 16 total pods across 3 namespaces (argocd, kube-system, poc-demo) |
| **Healthy Pods** | 14/16 pods in Running/Completed state |
| **Failed Pod** | `argocd-applicationset-controller-5959f79d67-fm75n` in CrashLoopBackOff |
| **Restart Count** | 824 restarts over 4 days 1 hour |
| **Exit Code** | 1 (Error) |
| **Error Message** | `failed to get restmapping: no matches for kind "ApplicationSet" in version "argoproj.io/v1alpha1"` |
| **Root Cause** | ApplicationSet CRD not installed in cluster |
| **ArgoCD Application** | hello-caipe is Synced and Healthy |
| **Application Pods** | hello-caipe-66898cfb9b-l8t2q and hello-caipe-66898cfb9b-w7jkl both Running (1/1) |
| **Resource Usage** | Total cluster: 24m CPU, 366Mi memory - all within normal ranges |
| **Warning Events** | 2 events: ApplicationSet BackOff, CoreDNS nameserver limit warning |

### Pod Status Breakdown

**ArgoCD Namespace (7 pods):**
- ✅ argocd-application-controller-0: Running (1/1)
- ❌ argocd-applicationset-controller-5959f79d67-fm75n: CrashLoopBackOff (0/1)
- ✅ argocd-dex-server-6f84fd5569-6wrzv: Running (1/1)
- ✅ argocd-notifications-controller-5856884878-nxz5d: Running (1/1)
- ✅ argocd-redis-86846d5986-7qttx: Running (1/1)
- ✅ argocd-repo-server-7d44c57bc8-brxhb: Running (1/1)
- ✅ argocd-server-6f78998d5b-w25v6: Running (1/1)

**kube-system Namespace (7 pods):**
- ✅ coredns-54996dc9b4-44bqm: Running (1/1)
- ✅ helm-install-traefik-c9b4w: Completed (0/1)
- ✅ helm-install-traefik-crd-9hsbd: Completed (0/1)
- ✅ local-path-provisioner-77b9867795-z74vb: Running (1/1)
- ✅ metrics-server-6dc596dfb8-rwqcg: Running (1/1)
- ✅ svclb-traefik-966fd6f3-rvl55: Running (2/2)
- ✅ traefik-59b7647586-2gt2h: Running (1/1)

**poc-demo Namespace (2 pods):**
- ✅ hello-caipe-66898cfb9b-l8t2q: Running (1/1)
- ✅ hello-caipe-66898cfb9b-w7jkl: Running (1/1)

### ArgoCD Application Status

**Application**: hello-caipe
- **Sync Status**: Synced
- **Health Status**: Healthy
- **Repository**: https://github.com/ponchotitlan/caipe-sentinel.git
- **Path**: app
- **Revision**: 07ab1593fdc28a85bd70a7b5c7471a9984fbbd26
- **Managed Resources**: 3 (Namespace, Service, Deployment)
- **Last Reconciled**: 2026-09-14T14:45:45Z

### Resource Consumption

Top resource consumers:
- argocd-application-controller: 4m CPU, 86Mi memory
- argocd-redis: 7m CPU, 5Mi memory
- metrics-server: 7m CPU, 31Mi memory
- coredns: 5m CPU, 21Mi memory

All resource usage is within normal operational ranges.

## Impact

**Operational Impact:**
- ApplicationSet functionality is unavailable - cannot use ApplicationSet CRDs for multi-app templating
- Core ArgoCD application management is unaffected - the application controller is healthy
- Managed applications (hello-caipe) are fully operational and healthy
- No user-facing service disruption

**Resource Impact:**
- Continuous restart loop consuming minimal resources (pod fails before significant resource allocation)
- 824 failed restart attempts creating noise in cluster events and logs

**Stability Impact:**
- ArgoCD control plane is partially degraded but functional for existing Application resources
- No impact on existing GitOps workflows using Application CRDs

## Action Taken

**Read-only assessment completed.** No infrastructure changes were made per agent security policy.

## Verification

**Current State Confirmed:**
- ✅ ArgoCD application controller: Healthy and managing applications
- ✅ Managed application hello-caipe: Synced and Healthy
- ✅ Application pods: Both replicas running normally
- ❌ ApplicationSet controller: Failing due to missing CRD
- ✅ All other cluster components: Operational

## Follow-up

### Recommended Next Steps

**Option 1: Install ApplicationSet CRD (if ApplicationSets are needed)**
```bash
# Verify ArgoCD version
kubectl get deployment argocd-applicationset-controller -n argocd -o jsonpath='{.spec.template.spec.containers[0].image}'

# Install ApplicationSet CRD matching ArgoCD version v3.5.2
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/crds/applicationset-crd.yaml
```

**Option 2: Remove ApplicationSet Controller (if ApplicationSets are not used)**
```bash
# Scale down the deployment if ApplicationSets are not needed
kubectl scale deployment argocd-applicationset-controller -n argocd --replicas=0
```

**Verification Steps After Remediation:**
1. Check pod status: `kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller`
2. Verify CRD installation: `kubectl get crd applicationsets.argoproj.io`
3. Check controller logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller --tail=50`
4. Monitor events: `kubectl get events -n argocd --field-selector type=Warning`

### Open Questions

1. **Was ApplicationSet functionality intentionally deployed?** The controller is present but the CRD is missing, suggesting incomplete installation.
2. **Are ApplicationSets required for this cluster?** If not, the controller can be safely removed.
3. **What caused the CRD to be missing?** Was it never installed, or was it removed?

### Risk Assessment

- **Low risk to production**: Managed applications are unaffected
- **Low urgency**: No user-facing impact
- **Medium priority**: Should be resolved to clean up cluster state and reduce noise

---

**Report Generated**: 2026-09-14 14:47 UTC  
**Cluster**: poncho-caipe  
**Namespaces Assessed**: 7 (argocd, default, kube-node-lease, kube-public, kube-system, mcp, poc-demo)  
**Total Pods**: 16  
**Health Score**: 87.5% (14/16 pods healthy)
