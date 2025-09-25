#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}GKE Test Drive Environment Deployment${NC}"
echo -e "${GREEN}=====================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform is required but not installed.${NC}"; exit 1; }
command -v gcloud >/dev/null 2>&1 || { echo -e "${RED}Google Cloud SDK is required but not installed.${NC}"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}Helm is required but not installed.${NC}"; exit 1; }

# Set project
PROJECT_ID="simplifymycloud-dev"
REGION="us-west1"
ZONE="us-west1-a"

echo -e "\n${YELLOW}Setting up GCP project...${NC}"
gcloud config set project ${PROJECT_ID}

# Enable required APIs
echo -e "\n${YELLOW}Enabling required GCP APIs...${NC}"
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable iap.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# Deploy infrastructure with Terraform
echo -e "\n${YELLOW}Deploying infrastructure with Terraform...${NC}"
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Get cluster credentials
echo -e "\n${YELLOW}Getting GKE cluster credentials...${NC}"
gcloud container clusters get-credentials gke-rancher-testdrive --zone=${ZONE} --project=${PROJECT_ID}

# Create Artifact Registry repository for container images
echo -e "\n${YELLOW}Creating Artifact Registry repository...${NC}"
gcloud artifacts repositories create gke-stats \
  --repository-format=docker \
  --location=${REGION} \
  --description="GKE stats website images" || true

# Configure Docker authentication
echo -e "\n${YELLOW}Configuring Docker authentication...${NC}"
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Build and push container images
echo -e "\n${YELLOW}Building and pushing container images...${NC}"
cd ../k8s/website

# Build backend image
docker build -f Dockerfile --target backend -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/gke-stats/backend:latest .
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/gke-stats/backend:latest

# Build frontend image
docker build -f Dockerfile --target frontend -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/gke-stats/frontend:latest .
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/gke-stats/frontend:latest

# Update deployment with correct image URLs
sed -i.bak "s|gcr.io/simplifymycloud-dev/gke-stats-backend:latest|${REGION}-docker.pkg.dev/${PROJECT_ID}/gke-stats/backend:latest|g" deployment.yaml
sed -i.bak "s|gcr.io/simplifymycloud-dev/gke-stats-frontend:latest|${REGION}-docker.pkg.dev/${PROJECT_ID}/gke-stats/frontend:latest|g" deployment.yaml

# Deploy website to GKE
echo -e "\n${YELLOW}Deploying website to GKE...${NC}"
kubectl apply -f deployment.yaml

# Install Rancher
echo -e "\n${YELLOW}Installing Rancher...${NC}"
cd ../rancher
chmod +x install-rancher.sh
./install-rancher.sh

# Get Load Balancer IP
echo -e "\n${YELLOW}Waiting for Load Balancer IP...${NC}"
for i in {1..30}; do
  LB_IP=$(kubectl get svc -n gke-stats frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  if [ ! -z "$LB_IP" ]; then
    break
  fi
  echo -n "."
  sleep 10
done

echo -e "\n\n${GREEN}=====================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}=====================================${NC}"

echo -e "\n${YELLOW}Access Information:${NC}"
echo -e "Website URL: http://${LB_IP}"
echo -e "Rancher URL: https://rancher.local (configure /etc/hosts with ingress IP)"

echo -e "\n${YELLOW}Bastion Host Access:${NC}"
echo -e "gcloud compute ssh poc-bastion --zone=${ZONE} --tunnel-through-iap --project=${PROJECT_ID}"

echo -e "\n${YELLOW}Important Notes:${NC}"
echo -e "- Add your email to allowed_iap_users in terraform/terraform.tfvars for IAP access"
echo -e "- The website shows live cluster statistics"
echo -e "- Rancher initial password: admin"
echo -e "- All management traffic goes through IAP"
echo -e "- Only the website is publicly accessible"

cd ../..