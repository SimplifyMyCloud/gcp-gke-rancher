#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}=====================================${NC}"
echo -e "${RED}Destroying GKE Test Drive Environment${NC}"
echo -e "${RED}=====================================${NC}"

# Set project
PROJECT_ID="simplifymycloud-dev"
REGION="us-west1"
ZONE="us-west1-a"

echo -e "\n${YELLOW}Setting up GCP project...${NC}"
gcloud config set project ${PROJECT_ID}

# Confirm destruction
read -p "Are you sure you want to destroy all resources? This cannot be undone. (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo -e "${YELLOW}Destruction cancelled.${NC}"
  exit 0
fi

# Delete Kubernetes resources
echo -e "\n${YELLOW}Deleting Kubernetes resources...${NC}"
kubectl delete namespace gke-stats --ignore-not-found=true
kubectl delete namespace cattle-system --ignore-not-found=true
kubectl delete namespace cert-manager --ignore-not-found=true
kubectl delete namespace ingress-nginx --ignore-not-found=true

# Delete Artifact Registry images
echo -e "\n${YELLOW}Deleting container images...${NC}"
gcloud artifacts repositories delete gke-stats \
  --location=${REGION} \
  --quiet || true

# Destroy infrastructure with Terraform
echo -e "\n${YELLOW}Destroying infrastructure with Terraform...${NC}"
cd terraform
terraform destroy -auto-approve

echo -e "\n${GREEN}=====================================${NC}"
echo -e "${GREEN}Environment destroyed successfully!${NC}"
echo -e "${GREEN}=====================================${NC}"

cd ..