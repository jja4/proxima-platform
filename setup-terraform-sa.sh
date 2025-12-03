#!/bin/bash
set -e

if [ -z "$PROJECT_ID" ]; then
  echo "Error: PROJECT_ID environment variable is not set."
  echo "Please set PROJECT_ID to your GCP project ID and rerun the script."
  exit 1
fi
echo "Authenticating with gcloud..."
gcloud auth login


PROJECT_ID="${PROJECT_ID}"
SA_NAME="terraform-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Using project: $PROJECT_ID"
echo ""
echo "Enabling required APIs..."

APIS=(
  "cloudresourcemanager.googleapis.com"
  "compute.googleapis.com"
  "container.googleapis.com"
  "artifactregistry.googleapis.com"
  "storage.googleapis.com"
  "iam.googleapis.com"
  "secretmanager.googleapis.com"
  "logging.googleapis.com"
  "monitoring.googleapis.com"
)

for api in "${APIS[@]}"; do
  echo "Enabling: $api"
  gcloud services enable $api --project=$PROJECT_ID
done

echo "APIs enabled"
echo ""
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
  "roles/iam.serviceAccountUser" 
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
echo ""
echo "Granting Terraform SA permission to use service accounts at project level..."
# This allows Terraform to use any service account in the project (both existing and ones it creates)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser" \
  --quiet

echo "Service account usage permission granted"
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
