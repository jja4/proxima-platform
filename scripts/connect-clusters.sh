#!/bin/bash
# Connect to GKE clusters and verify ArgoCD deployment
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="europe-west3"
ZONE="europe-west3-a"

echo "=== Connecting to Management Cluster ==="
gcloud container clusters get-credentials ml-platform-management \
  --zone=$ZONE \
  --project=$PROJECT_ID

# Rename context for clarity
kubectl config rename-context gke_${PROJECT_ID}_${ZONE}_ml-platform-management management 2>/dev/null || true

echo "=== Connecting to Workload Cluster ==="
gcloud container clusters get-credentials ml-platform-workload \
  --region=$REGION \
  --project=$PROJECT_ID

# Rename context for clarity
kubectl config rename-context gke_${PROJECT_ID}_${REGION}_ml-platform-workload workload 2>/dev/null || true

echo ""
echo "✅ Connected to both clusters!"
echo ""
echo "Available contexts:"
kubectl config get-contexts | grep -E "management|workload"
echo ""
echo "Current context: $(kubectl config current-context)"
