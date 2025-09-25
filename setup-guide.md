# GKE Test Drive - Setup Guide

## Quick Setup (5 minutes)

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd gcp-gke-rancher
   ```

2. **Configure access**:
   ```bash
   # Edit terraform/terraform.tfvars
   # Add your email to allowed_iap_users
   ```

3. **Run deployment**:
   ```bash
   ./deploy.sh
   ```

4. **Access the website**:
   - The script will output the Load Balancer IP
   - Open in browser: `http://<LB_IP>`

## Manual Setup Steps

If you prefer to deploy components individually:

### Step 1: Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Step 2: Get Cluster Credentials
```bash
gcloud container clusters get-credentials gke-rancher-testdrive \
  --zone=us-west1-a \
  --project=simplifymycloud-dev
```

### Step 3: Deploy Rancher
```bash
cd ../k8s/rancher
./install-rancher.sh
```

### Step 4: Build and Deploy Website
```bash
cd ../website

# Build images
docker build -f Dockerfile --target backend -t backend:latest .
docker build -f Dockerfile --target frontend -t frontend:latest .

# Push to registry (update PROJECT_ID)
docker tag backend:latest us-west1-docker.pkg.dev/PROJECT_ID/gke-stats/backend:latest
docker tag frontend:latest us-west1-docker.pkg.dev/PROJECT_ID/gke-stats/frontend:latest
docker push us-west1-docker.pkg.dev/PROJECT_ID/gke-stats/backend:latest
docker push us-west1-docker.pkg.dev/PROJECT_ID/gke-stats/frontend:latest

# Deploy to Kubernetes
kubectl apply -f deployment.yaml
```

## Verification Steps

1. **Check cluster is running**:
   ```bash
   kubectl get nodes
   ```

2. **Verify Rancher is installed**:
   ```bash
   kubectl get pods -n cattle-system
   ```

3. **Check website deployment**:
   ```bash
   kubectl get pods -n gke-stats
   kubectl get svc -n gke-stats
   ```

## Access Methods

### Public Website
- No authentication required
- Shows live cluster statistics
- Available at: `http://<LOAD_BALANCER_IP>`

### Rancher Console (Secure Access)
1. Create port forward tunnel:
   ```bash
   kubectl port-forward -n cattle-system svc/rancher 8443:443
   ```
2. Access: https://localhost:8443
3. Login: admin/admin

Note: Rancher is intentionally not exposed to the internet for security.

### Cluster Management via Bastion
```bash
gcloud compute ssh poc-bastion \
  --zone=us-west1-a \
  --tunnel-through-iap
```

From bastion:
```bash
# Kubectl is pre-configured
kubectl get nodes
kubectl get pods --all-namespaces
```