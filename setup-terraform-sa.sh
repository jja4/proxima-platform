#!/bin/bash
set -e

PROJECT_ID="proxima-platform-479922"
SA_NAME="terraform-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Creating service account: $SA_EMAIL"

gcloud iam service-accounts create $SA_NAME \
  --project=$PROJECT_ID \
  --display-name="Terraform Service Account"

echo "Service account created"
echo "Granting roles..."

ROLES=(
  "roles/compute.networkAdmin"
  "roles/compute.securityAdmin"
  "roles/container.admin"
  "roles/artifactregistry.admin"
  "roles/storage.admin"
  "roles/iam.serviceAccountAdmin"
  "roles/iam.serviceAccountKeyAdmin"
  "roles/iam.securityAdmin"
  "roles/monitoring.admin"
  "roles/secretmanager.admin"
  "roles/logging.admin"
  "roles/container.developer"
)

for role in "${ROLES[@]}"; do
  echo "Granting: $role"
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$role" \
    --quiet
done

echo "All roles granted"
echo "Creating service account key..."

gcloud iam service-accounts keys create terraform-key.json \
  --project=$PROJECT_ID \
  --iam-account="$SA_EMAIL"

echo "Key saved to: terraform-key.json"
echo ""
echo "Next steps:"
echo "1. cp terraform-key.json /Users/macos/Code/gcp-keys/proxima-terraform-key.json"
echo "2. export GOOGLE_APPLICATION_CREDENTIALS=/Users/macos/Code/gcp-keys/proxima-terraform-key.json"
echo "3. rm terraform-key.json"
