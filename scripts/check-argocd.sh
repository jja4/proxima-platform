#!/bin/bash
# Check ArgoCD status and get admin password
set -e

echo "=== Switching to Management Cluster ==="
kubectl config use-context management

echo ""
echo "=== Checking ArgoCD Pods ==="
kubectl get pods -n argocd

echo ""
echo "=== Checking ArgoCD Applications ==="
kubectl get applications -n argocd

echo ""
echo "=== Checking ArgoCD ApplicationSets ==="
kubectl get applicationsets -n argocd

echo ""
echo "=== Checking AppProjects ==="
kubectl get appprojects -n argocd

echo ""
echo "=== Getting ArgoCD Admin Password ==="
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "Secret not found - ArgoCD may still be initializing")

echo ""
echo "=================================="
echo "ArgoCD UI Access:"
echo "=================================="
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo ""
echo "To access UI, run in another terminal:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Then open: http://localhost:8080"
echo "=================================="
