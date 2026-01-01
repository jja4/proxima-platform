# Golden Triangle MVP - Job Submission First

Build minimal Golden Triangle (Backstage → ArgoCD → Crossplane) for current job submission workflow, then extend to Jupyter environments in Phase 2.

## Steps

### 1. Week 1 - Dual Cluster Infrastructure

Create [terraform/modules/management-cluster](terraform/modules/management-cluster) (Standard GKE, zonal us-central1-a, single e2-micro node); create [terraform/modules/workload-cluster](terraform/modules/workload-cluster) (Autopilot, zonal us-central1-a); configure Workload Identity for both clusters in [terraform/modules/gke/main.tf](terraform/modules/gke/main.tf); output kubeconfig paths for both clusters; request T4 GPU quota (1 GPU, us-central1).

### 2. Week 2 - GitOps with ArgoCD

Install ArgoCD on management cluster via Helm in [gitops/bootstrap/argocd.yaml](gitops/bootstrap/argocd.yaml); create monorepo structure: `gitops/management/` (ArgoCD, Crossplane, Backstage, Prometheus), `gitops/workload/` (Ray cluster, jobs namespace, network policies), `gitops/bootstrap/root-app.yaml` (app-of-apps pointing to both); register workload cluster as ArgoCD remote cluster using service account secret; deploy shared Ray cluster to workload cluster via [gitops/workload/ray/ray-cluster.yaml](gitops/workload/ray/ray-cluster.yaml).

### 3. Week 3 - Crossplane Job Provisioning

Deploy Crossplane to management cluster in [gitops/management/crossplane/](gitops/management/crossplane/); install GCP provider and ProviderConfig with Workload Identity; create XRD [PhysicsJob API](gitops/management/crossplane/apis/physics-job.yaml) with fields: `jobName`, `image`, `command`, `gpuCount`, `cpuLimit`, `memoryLimit`, `gcsOutputBucket`; create Composition that provisions: GCS bucket with job name prefix, ServiceAccount with storage admin role, RayJob CRD on workload cluster with T4 GPU request, cost tracking labels.

### 4. Week 4 - Backstage Portal Integration

Deploy Backstage to management cluster via [gitops/management/backstage/](gitops/management/backstage/); create Software Template [physics-job-template](gitops/management/backstage/templates/physics-job/template.yaml) with form fields matching PhysicsJob XRD; configure template to commit PhysicsJob CR to Git repository; install Kubernetes plugin showing workload cluster resources; add ArgoCD plugin displaying sync status; test full workflow: Backstage form → Git commit → ArgoCD syncs → Crossplane provisions → Job runs on Ray.

### 5. Validate & Prepare Jupyter Phase

Migrate existing [docs/examples/stellar_optimization](docs/examples/stellar_optimization) to new workflow via Backstage; measure end-to-end time (form submit → job complete); document in [docs/PLATFORM_USAGE.md](docs/PLATFORM_USAGE.md); measure cost per job run; create Phase 2 design doc in [docs/JUPYTER_INTEGRATION.md](docs/JUPYTER_INTEGRATION.md) specifying JupyterEnvironment XRD and shared Ray cluster connection pattern.