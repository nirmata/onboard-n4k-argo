# Kyverno Deployment - Quick Start Guide

## ✅ Application Created Successfully!

Your Kyverno ArgoCD application has been deployed. Here's how to monitor and verify the deployment.

## 📊 Quick Monitoring Commands

### 1. Check ArgoCD Application Status

```bash
# View application summary
kubectl get application -n argocd kyverno

# Get detailed application info
kubectl describe application -n argocd kyverno

# Check sync and health status
kubectl get application -n argocd kyverno -o jsonpath='{.status.sync.status}' && echo
kubectl get application -n argocd kyverno -o jsonpath='{.status.health.status}' && echo
```

### 2. Monitor Kyverno Pods

```bash
# List all Kyverno pods
kubectl get pods -n kyverno

# Watch pods in real-time
kubectl get pods -n kyverno -w

# Check pod status with details
kubectl get pods -n kyverno -o wide
```

### 3. Check Deployments and Services

```bash
# List deployments
kubectl get deployments -n kyverno

# List services
kubectl get svc -n kyverno

# List all resources
kubectl get all -n kyverno
```

### 4. View Logs

```bash
# Admission Controller logs
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller --tail=100 -f

# Background Controller logs
kubectl logs -n kyverno -l app.kubernetes.io/component=background-controller --tail=100 -f

# Reports Controller logs
kubectl logs -n kyverno -l app.kubernetes.io/component=reports-controller --tail=100 -f

# Cleanup Controller logs
kubectl logs -n kyverno -l app.kubernetes.io/component=cleanup-controller --tail=100 -f

# Reports Server logs
kubectl logs -n kyverno -l app.kubernetes.io/name=reports-server --tail=100 -f
```

### 5. Verify Installation

```bash
# Check Kyverno version
kubectl get pods -n kyverno -l app.kubernetes.io/component=admission-controller -o jsonpath='{.items[0].spec.containers[0].image}'

# Check CRDs
kubectl get crd | grep kyverno

# Check API Services
kubectl get apiservices | grep kyverno
kubectl get apiservices | grep wgpolicyk8s

# Check webhooks
kubectl get validatingwebhookconfigurations | grep kyverno
kubectl get mutatingwebhookconfigurations | grep kyverno
```

## 🔧 Use Monitoring Script

Run the provided monitoring script for a comprehensive status check:

```bash
./argocd/monitor-deployment.sh
```

## 📈 Expected Deployment Timeline

1. **Namespace Creation** (5-10 seconds)
   - `kyverno` namespace is created

2. **CRDs Installation** (10-30 seconds)
   - Kyverno CRDs are installed
   - Reports CRDs are installed
   - PolicyReport CRDs are installed

3. **Reports Server Deployment** (30-60 seconds)
   - etcd StatefulSet (if enabled)
   - Reports Server Deployment
   - API Services

4. **Kyverno Controllers** (1-2 minutes)
   - Admission Controller
   - Background Controller
   - Cleanup Controller
   - Reports Controller

5. **Webhooks Configuration** (30 seconds)
   - ValidatingWebhookConfiguration
   - MutatingWebhookConfiguration

**Total Expected Time**: 2-4 minutes

## ✅ Verify Successful Deployment

All pods should be in `Running` state and `Ready`:

```bash
kubectl get pods -n kyverno
```

Expected output (example):
```
NAME                                               READY   STATUS    RESTARTS   AGE
kyverno-admission-controller-xxxxx                 1/1     Running   0          2m
kyverno-background-controller-xxxxx                1/1     Running   0          2m
kyverno-cleanup-controller-xxxxx                   1/1     Running   0          2m
kyverno-reports-controller-xxxxx                   1/1     Running   0          2m
reports-server-xxxxx                               1/1     Running   0          3m
```

Check ArgoCD Application Health:
```bash
kubectl get application -n argocd kyverno -o jsonpath='{.status.health.status}'
# Should output: Healthy
```

## 🔄 Common Operations

### Sync Application Manually

```bash
# If using ArgoCD CLI
argocd app sync kyverno

# Using kubectl
kubectl patch application kyverno -n argocd -p '{"operation":{"sync":{"prune":true}}}' --type=merge
```

### Refresh Application

```bash
# Force ArgoCD to check Git repository
argocd app get kyverno --refresh
```

### View Sync Differences

```bash
argocd app diff kyverno
```

### Restart Kyverno Components

```bash
# Restart admission controller
kubectl rollout restart deployment kyverno-admission-controller -n kyverno

# Restart all controllers
kubectl rollout restart deployment -n kyverno
```

## 🐛 Troubleshooting

### Application is Out of Sync

```bash
# Check what's different
kubectl describe application -n argocd kyverno | grep -A 20 "Conditions:"

# Force sync
argocd app sync kyverno --force
```

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n kyverno

# Check pod logs
kubectl logs <pod-name> -n kyverno

# Check resource constraints
kubectl top pods -n kyverno
```

### Webhooks Not Working

```bash
# Check webhook configurations
kubectl get validatingwebhookconfigurations -o yaml | grep -A 30 kyverno

# Check webhook service
kubectl get svc -n kyverno kyverno-svc

# Check webhook endpoint
kubectl get endpoints -n kyverno kyverno-svc
```

### API Services Unavailable

```bash
# Check API services
kubectl get apiservices | grep kyverno
kubectl get apiservices | grep wgpolicyk8s

# Check reports-server
kubectl get pods -n kyverno -l app.kubernetes.io/name=reports-server
kubectl logs -n kyverno -l app.kubernetes.io/name=reports-server
```

## 🧪 Test Kyverno Installation

Create a test policy:

```bash
kubectl create -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: Audit
  rules:
  - name: check-for-labels
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Label 'app' is required"
      pattern:
        metadata:
          labels:
            app: "?*"
EOF
```

Test the policy:

```bash
# This should fail (Audit mode, so it creates with warning)
kubectl run test-pod --image=nginx

# Check policy report
kubectl get policyreport -A

# Delete test resources
kubectl delete pod test-pod
kubectl delete clusterpolicy require-labels
```

## 📊 Access ArgoCD UI

```bash
# Port forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Open in browser
# https://localhost:8080
# Username: admin
# Password: (from above command)
```

## 📚 Next Steps

1. ✅ Verify all components are healthy
2. 📝 Create your first Kyverno policies
3. 📊 Set up monitoring (Prometheus/Grafana)
4. 🔒 Configure policy exceptions if needed
5. 📈 Review policy reports regularly

## 🔗 Useful Links

- [Kyverno Documentation](https://kyverno.io/docs/)
- [Kyverno Policies](https://kyverno.io/policies/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Troubleshooting Guide](https://kyverno.io/docs/troubleshooting/)

## 🆘 Getting Help

If you encounter issues:

1. Check the logs: `kubectl logs -n kyverno -l app.kubernetes.io/part-of=kyverno`
2. Check ArgoCD application status: `kubectl describe application -n argocd kyverno`
3. Review Kyverno documentation: https://kyverno.io/docs/troubleshooting/
4. Check GitHub issues: https://github.com/kyverno/kyverno/issues

