#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Monitoring Kyverno ArgoCD Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check ArgoCD Application Status
echo -e "${YELLOW}1. ArgoCD Application Status:${NC}"
kubectl get application -n argocd kyverno
echo ""

# Check Application Health
echo -e "${YELLOW}2. Application Health & Sync Status:${NC}"
kubectl get application -n argocd kyverno -o jsonpath='{.status.health.status}' && echo " (Health)"
kubectl get application -n argocd kyverno -o jsonpath='{.status.sync.status}' && echo " (Sync)"
echo ""

# Check Kyverno Namespace
echo -e "${YELLOW}3. Kyverno Namespace:${NC}"
kubectl get namespace kyverno 2>/dev/null || echo "Namespace not yet created"
echo ""

# Check Kyverno Pods
echo -e "${YELLOW}4. Kyverno Pods:${NC}"
kubectl get pods -n kyverno 2>/dev/null || echo "Pods not yet created"
echo ""

# Check Kyverno Deployments
echo -e "${YELLOW}5. Kyverno Deployments:${NC}"
kubectl get deployments -n kyverno 2>/dev/null || echo "Deployments not yet created"
echo ""

# Check Kyverno CRDs
echo -e "${YELLOW}6. Kyverno CRDs:${NC}"
kubectl get crd | grep kyverno.io | head -5
echo ""

# Check API Services
echo -e "${YELLOW}7. Kyverno API Services:${NC}"
kubectl get apiservices | grep kyverno
kubectl get apiservices | grep wgpolicyk8s
echo ""

# Check Recent Events
echo -e "${YELLOW}8. Recent Events in kyverno namespace:${NC}"
kubectl get events -n kyverno --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "No events yet"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Monitoring Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "To watch pods in real-time:"
echo "  kubectl get pods -n kyverno -w"
echo ""
echo "To check application sync status:"
echo "  kubectl describe application -n argocd kyverno"
echo ""
echo "To view Kyverno logs:"
echo "  kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller --tail=50"
echo ""

