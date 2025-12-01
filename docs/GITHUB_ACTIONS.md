# GitHub Actions Setup

This document describes the required GitHub Actions configuration for CI/CD.

## Required Secrets

Configure these secrets in your GitHub repository settings:
`Settings` → `Secrets and variables` → `Actions` → `New repository secret`

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `GCP_PROJECT_ID` | Your GCP project ID | `gcloud config get-value project` |
| `GCP_SA_KEY` | Service account JSON key | See below |

## Creating the Service Account

```bash
# Set variables
export PROJECT_ID=$(gcloud config get-value project)
export SA_NAME="github-actions"
export SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Create service account
gcloud iam service-accounts create ${SA_NAME} \
  --display-name="GitHub Actions CI/CD"

# Grant required roles
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/container.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/artifactregistry.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

# For Terraform state bucket access
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"

# Create and download key
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=${SA_EMAIL}

# Display for copying to GitHub
cat github-actions-key.json
```

## Adding Secrets to GitHub

1. Go to your repository on GitHub
2. Navigate to `Settings` → `Secrets and variables` → `Actions`
3. Click `New repository secret`
4. Add `GCP_PROJECT_ID` with your project ID
5. Add `GCP_SA_KEY` with the entire contents of `github-actions-key.json`

## Workflows

### Terraform CI/CD (`.github/workflows/terraform.yml`)

Triggers on:
- Push to `main` or `develop` branches (changes to `terraform/**`)
- Pull requests to `main` (changes to `terraform/**`)

Jobs:
1. **terraform-validate**: Format check and validation
2. **terraform-test**: Run `terraform test` for infrastructure tests
3. **terraform-plan**: Show planned changes (PRs only)
4. **terraform-apply**: Apply changes (main branch only)

### Build Workloads (`.github/workflows/build-workloads.yml`)

Triggers on:
- Push to `main` or `develop` branches (changes to `docs/examples/**`)
- Manual dispatch with workload name

Builds and pushes Docker images to Artifact Registry.

## Security Best Practices

1. **Rotate keys regularly**: Create new keys every 90 days
2. **Least privilege**: Only grant necessary roles
3. **Monitor usage**: Check Cloud Audit Logs for SA activity
4. **Delete unused keys**: Remove old keys after rotation

```bash
# List existing keys
gcloud iam service-accounts keys list --iam-account=${SA_EMAIL}

# Delete old key
gcloud iam service-accounts keys delete KEY_ID --iam-account=${SA_EMAIL}
```

## Troubleshooting

### "Permission denied" errors

Check that the service account has the required roles:
```bash
gcloud projects get-iam-policy ${PROJECT_ID} \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:${SA_EMAIL}"
```

### Terraform state access errors

Ensure the state bucket exists and SA has access:
```bash
gsutil ls gs://${PROJECT_ID}-terraform-state
```

### Docker push failures

Verify Artifact Registry access:
```bash
gcloud auth activate-service-account --key-file=github-actions-key.json
gcloud auth configure-docker ${REGION}-docker.pkg.dev
```
