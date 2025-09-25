# Google Kubernetes Engine (GKE) Configuration

## Overview

This document details the GKE cluster configuration for the test drive environment. The cluster is designed as a secure, private POC environment with all management traffic routed through Identity-Aware Proxy (IAP).

## Cluster Architecture

```
┌─────────────────────────────────────────┐
│          Internet                       │
└────────────┬───────────────┬────────────┘
             │               │
    ┌────────▼────┐   ┌─────▼──────┐
    │  Cloud NAT  │   │    IAP     │
    └────────┬────┘   └─────┬──────┘
             │               │
    ┌────────▼───────────────▼────────────┐
    │         VPC Network (10.0.0.0/20)   │
    ├──────────────────────────────────────┤
    │  Private Subnet: 10.0.0.0/20        │
    │  Pod Range: 10.4.0.0/14             │
    │  Service Range: 10.8.0.0/20         │
    └────────┬─────────────────────────────┘
             │
    ┌────────▼─────────────────────────────┐
    │   GKE Private Cluster                │
    │   Name: gke-rancher-testdrive        │
    │   Nodes: 3 x e2-standard-4           │
    │   Zone: us-west1-a                   │
    └──────────────────────────────────────┘
```

## Cluster Specifications

### Basic Configuration

| Setting | Value |
|---------|-------|
| Cluster Name | gke-rancher-testdrive |
| Location | us-west1-a (Zonal) |
| Kubernetes Version | Latest stable (auto) |
| Release Channel | Regular |
| Network | poc-vpc |
| Subnet | poc-subnet |
| Project | simplifymycloud-dev |

### Node Pool Configuration

| Setting | Value |
|---------|-------|
| Name | gke-rancher-testdrive-node-pool |
| Machine Type | e2-standard-4 |
| Node Count | 3 |
| Disk Size | 100 GB |
| Disk Type | pd-standard |
| Preemptible | Yes (cost optimization) |
| Auto-repair | Enabled |
| Auto-upgrade | Enabled |

### Network Configuration

| Component | CIDR Range | Purpose |
|-----------|------------|---------|
| VPC Subnet | 10.0.0.0/20 | Node IP addresses |
| Pod Range | 10.4.0.0/14 | Pod IP addresses |
| Service Range | 10.8.0.0/20 | Service ClusterIPs |
| Master Range | 172.16.0.0/28 | Control plane IPs |

## Security Features

### Private Cluster Configuration

```hcl
private_cluster_config {
  enable_private_nodes    = true  # Nodes have no public IPs
  enable_private_endpoint = false # Master accessible from internet
  master_ipv4_cidr_block = "172.16.0.0/28"
}
```

**Benefits**:
- Nodes isolated from internet
- Reduced attack surface
- Outbound via Cloud NAT only
- Master API secured with authorized networks

### Identity-Aware Proxy (IAP)

All administrative access is protected by IAP:

```hcl
resource "google_compute_firewall" "allow_iap" {
  source_ranges = ["35.235.240.0/20"]  # Google IAP range
  target_tags   = ["iap-access"]

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }
}
```

### Workload Identity

Enabled for secure pod-to-GCP service authentication:

```hcl
workload_identity_config {
  workload_pool = "${var.project_id}.svc.id.goog"
}
```

### Service Accounts

Two dedicated service accounts with minimal permissions:

1. **Node Service Account** (`poc-gke-node-sa`)
   - `roles/logging.logWriter`
   - `roles/monitoring.metricWriter`
   - `roles/monitoring.viewer`

2. **Bastion Service Account** (`poc-bastion-sa`)
   - `roles/container.admin`

## Access Methods

### Via Bastion Host

Primary method for cluster management:

```bash
# SSH to bastion via IAP
gcloud compute ssh poc-bastion \
  --zone=us-west1-a \
  --tunnel-through-iap \
  --project=simplifymycloud-dev

# From bastion, kubectl is pre-configured
kubectl get nodes
kubectl get pods --all-namespaces
```

### Direct kubectl (with IAP tunnel)

Set up local access:

```bash
# Get credentials
gcloud container clusters get-credentials gke-rancher-testdrive \
  --zone=us-west1-a \
  --project=simplifymycloud-dev

# Create IAP tunnel for API access
gcloud compute ssh poc-bastion \
  --zone=us-west1-a \
  --tunnel-through-iap \
  --ssh-flag="-L 8888:127.0.0.1:8888" \
  --ssh-flag="-N" \
  --ssh-flag="-f"

# Configure kubectl to use tunnel
kubectl config set-cluster gke-rancher-testdrive \
  --server=https://127.0.0.1:8888
```

### Via Rancher UI

Access through Rancher management console:
1. Log into Rancher at `https://rancher.local`
2. Navigate to cluster management
3. Use built-in kubectl shell

## Monitoring & Logging

### Google Cloud Operations

Automatically integrated:
- **Cloud Logging**: All container logs
- **Cloud Monitoring**: Metrics and dashboards
- **Cloud Trace**: Distributed tracing (if enabled)

View in GCP Console:
```bash
# Open monitoring dashboard
gcloud compute url-maps list --project=simplifymycloud-dev

# View logs
gcloud logging read "resource.type=k8s_cluster AND resource.labels.cluster_name=gke-rancher-testdrive" \
  --limit=50 \
  --project=simplifymycloud-dev
```

### kubectl Commands

```bash
# Node metrics
kubectl top nodes

# Pod metrics
kubectl top pods --all-namespaces

# Cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Node details
kubectl describe nodes

# Cluster info
kubectl cluster-info
```

## Networking Details

### Firewall Rules

| Rule Name | Purpose | Source | Ports |
|-----------|---------|--------|-------|
| poc-allow-iap | IAP access | 35.235.240.0/20 | 22, 3389 |
| poc-allow-internal | Internal communication | 10.0.0.0/8 | All |
| poc-allow-health-checks | Load balancer health | 35.191.0.0/16, 130.211.0.0/22 | All TCP |

### Cloud NAT Configuration

Enables outbound internet access for private nodes:

```hcl
resource "google_compute_router_nat" "nat" {
  name                               = "poc-nat"
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
```

## Cost Optimization

### Preemptible Nodes

Using preemptible VMs for 70% cost savings:
- Automatic replacement if preempted
- Suitable for POC/dev environments
- 24-hour maximum lifetime

### Resource Sizing

Conservative sizing for POC:
- e2-standard-4: 4 vCPUs, 16GB RAM
- Sufficient for Rancher + demo apps
- Easy to scale up if needed

### Estimated Costs

| Component | Monthly Cost |
|-----------|-------------|
| GKE Management | $0 (zonal) |
| 3x e2-standard-4 (preemptible) | ~$90 |
| Cloud NAT | ~$45 |
| Network Egress | ~$10 |
| **Total** | **~$145** |

## Scaling Options

### Manual Scaling

```bash
# Scale node pool
gcloud container clusters resize gke-rancher-testdrive \
  --node-pool=gke-rancher-testdrive-node-pool \
  --num-nodes=5 \
  --zone=us-west1-a

# Via kubectl (if cluster autoscaler enabled)
kubectl scale deployment my-app --replicas=10
```

### Terraform Scaling

Update `terraform/terraform.tfvars`:
```hcl
gke_node_count = 5
gke_node_machine_type = "e2-standard-8"
```

Then apply:
```bash
cd terraform
terraform plan
terraform apply
```

## Maintenance Operations

### Cluster Upgrades

GKE handles automatic upgrades:
```bash
# Check available versions
gcloud container get-server-config --zone=us-west1-a

# Manual upgrade (if needed)
gcloud container clusters upgrade gke-rancher-testdrive \
  --master \
  --cluster-version=1.27.3-gke.100 \
  --zone=us-west1-a
```

### Node Pool Maintenance

```bash
# Cordon node (prevent new pods)
kubectl cordon <node-name>

# Drain node (move pods)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Delete node from pool
gcloud compute instances delete <node-name> --zone=us-west1-a
```

### Backup Strategies

1. **Cluster Configuration**:
   ```bash
   # Export cluster config
   kubectl get all --all-namespaces -o yaml > cluster-backup.yaml
   ```

2. **Persistent Volume Snapshots**:
   ```bash
   # Create disk snapshot
   gcloud compute disks snapshot <disk-name> \
     --snapshot-names=<snapshot-name> \
     --zone=us-west1-a
   ```

3. **GKE Backup Service** (if enabled):
   ```bash
   gcloud beta container backup-restore backups create my-backup \
     --cluster=gke-rancher-testdrive \
     --location=us-west1-a \
     --backup-plan=my-backup-plan
   ```

## Troubleshooting

### Common Issues

#### Nodes Not Ready
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check kubelet logs
gcloud compute ssh <node-name> --command="sudo journalctl -u kubelet -f"
```

#### Pod Scheduling Issues
```bash
# Check pod events
kubectl describe pod <pod-name>

# Check resource availability
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check pod anti-affinity rules
kubectl get pod <pod-name> -o yaml | grep -A 10 affinity
```

#### Network Connectivity
```bash
# Test internal DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes

# Test external connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://www.google.com

# Check network policies
kubectl get networkpolicies --all-namespaces
```

### Debug Commands

```bash
# Enable verbose kubectl output
kubectl get pods -v=8

# Access node directly
gcloud compute ssh <node-name> --zone=us-west1-a

# View cloud NAT logs
gcloud logging read "resource.type=nat_gateway" --limit=50

# Check IAP access logs
gcloud logging read "protoPayload.methodName=AuthorizeUser" --limit=50
```

## Best Practices

### Security
1. Regularly update cluster and nodes
2. Use Workload Identity for pod authentication
3. Implement network policies
4. Enable Binary Authorization
5. Use private container registry

### Performance
1. Use SSD persistent disks for databases
2. Configure pod resource requests/limits
3. Use horizontal pod autoscaling
4. Implement pod disruption budgets

### Reliability
1. Deploy across multiple zones (production)
2. Use pod anti-affinity rules
3. Implement health checks
4. Configure proper restart policies

### Cost Management
1. Use preemptible nodes for non-critical workloads
2. Implement cluster autoscaling
3. Right-size node pools
4. Use committed use discounts (production)

## Production Migration Checklist

- [ ] Switch to regional cluster for HA
- [ ] Use standard (non-preemptible) nodes
- [ ] Enable cluster autoscaling
- [ ] Configure backup strategy
- [ ] Implement monitoring/alerting
- [ ] Set up log aggregation
- [ ] Configure network policies
- [ ] Enable Binary Authorization
- [ ] Implement CI/CD pipeline
- [ ] Set up disaster recovery
- [ ] Configure DNS properly
- [ ] Obtain SSL certificates
- [ ] Implement secrets management
- [ ] Set up RBAC policies
- [ ] Configure resource quotas

## Additional Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [GKE Security Hardening](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
- [GKE Pricing Calculator](https://cloud.google.com/products/calculator)