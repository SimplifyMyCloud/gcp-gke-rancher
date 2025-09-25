# Rancher Management Platform

## Overview

Rancher is a complete Kubernetes management platform that makes it easy to deploy and manage Kubernetes clusters anywhere. In this POC environment, Rancher provides a user-friendly interface to manage the GKE cluster.

## Architecture

```
┌─────────────────────────────────────┐
│         Rancher Server              │
│    (Deployed in cattle-system)      │
├─────────────────────────────────────┤
│      NGINX Ingress Controller       │
│    (Handles external traffic)       │
├─────────────────────────────────────┤
│         Cert-Manager                │
│    (Manages SSL certificates)       │
├─────────────────────────────────────┤
│         GKE Cluster                 │
│    (gke-rancher-testdrive)         │
└─────────────────────────────────────┘
```

## Installation Details

### Components Deployed

1. **Cert-Manager** (v1.13.3)
   - Automated certificate management
   - Self-signed certificates for POC
   - Namespace: `cert-manager`

2. **NGINX Ingress Controller** (v1.9.4)
   - External access point for Rancher
   - Load balancer for incoming traffic
   - Namespace: `ingress-nginx`

3. **Rancher Server** (Latest)
   - Kubernetes management interface
   - Single replica for POC
   - Namespace: `cattle-system`

### Configuration

The Rancher installation uses these key settings:

```yaml
hostname: rancher.local
replicas: 1
bootstrapPassword: "admin"
ingress:
  tls:
    source: secret
resources:
  requests:
    memory: "2Gi"
    cpu: "1"
  limits:
    memory: "4Gi"
    cpu: "2"
```

## Access Methods

### Secure Access via Port Forward (Required)

Rancher is not publicly accessible and requires a secure tunnel for access:

1. **Create Port Forward**:
   ```bash
   kubectl port-forward -n cattle-system svc/rancher 8443:443
   ```

2. **Access Rancher**:
   - URL: `https://localhost:8443`
   - Initial Username: `admin`
   - Initial Password: `admin`

See [IAP Access Documentation](./iap-access.md) for detailed instructions and alternative methods.

### CLI Access via kubectl

From the bastion host:
```bash
# Check Rancher status
kubectl get pods -n cattle-system

# View Rancher logs
kubectl logs -n cattle-system deployment/rancher

# Get Rancher version
kubectl get deployment -n cattle-system rancher -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Features Available

### Cluster Management
- View cluster health and metrics
- Manage nodes and workloads
- Configure cluster settings
- Access cluster shell

### Application Management
- Deploy applications from catalog
- Manage Helm charts
- Configure app settings
- Monitor deployments

### Security & Access
- User management (local auth)
- RBAC configuration
- Project isolation
- Security policies

### Monitoring
- Basic cluster metrics
- Resource utilization
- Pod and node status
- Event logs

## Common Operations

### Reset Admin Password

If you need to reset the admin password:

```bash
# From bastion host
kubectl -n cattle-system exec $(kubectl -n cattle-system get pods -l app=rancher -o name | head -1) -- reset-password
```

### Enable External Authentication

For production, consider enabling external auth:

1. Navigate to **Authentication & Security** > **Authentication**
2. Select provider (Google, GitHub, LDAP, etc.)
3. Configure provider settings
4. Test authentication

### Install Monitoring

To add Prometheus/Grafana monitoring:

1. Go to **Cluster Tools**
2. Find **Monitoring** in the list
3. Click **Install**
4. Configure resource limits
5. Wait for deployment

### Backup Rancher

To backup Rancher configuration:

```bash
# Backup etcd (if using internal)
kubectl -n cattle-system exec $(kubectl -n cattle-system get pods -l app=rancher -o name | head -1) -- backup

# Export Rancher resources
kubectl get -n cattle-system secrets,configmaps,deployments,services -o yaml > rancher-backup.yaml
```

## Troubleshooting

### Rancher Pod Not Starting

1. **Check pod status**:
   ```bash
   kubectl describe pod -n cattle-system -l app=rancher
   ```

2. **View logs**:
   ```bash
   kubectl logs -n cattle-system -l app=rancher --tail=50
   ```

3. **Check resources**:
   ```bash
   kubectl top pods -n cattle-system
   ```

### Certificate Issues

1. **Verify cert-manager**:
   ```bash
   kubectl get pods -n cert-manager
   kubectl get certificates -A
   ```

2. **Recreate certificate**:
   ```bash
   kubectl delete secret -n cattle-system tls-rancher-ingress
   # Then rerun install script
   ```

### Cannot Access UI

1. **Check ingress**:
   ```bash
   kubectl get ingress -n cattle-system
   kubectl describe ingress -n cattle-system rancher
   ```

2. **Verify NGINX controller**:
   ```bash
   kubectl get svc -n ingress-nginx
   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
   ```

### High Resource Usage

1. **Check current usage**:
   ```bash
   kubectl top pod -n cattle-system
   ```

2. **Adjust resources**:
   ```bash
   kubectl edit deployment -n cattle-system rancher
   # Modify resources section
   ```

## Security Considerations

### POC Setup Limitations
- Self-signed certificates
- Default admin password
- Single replica (no HA)
- Local authentication only

### Production Recommendations

1. **SSL Certificates**
   - Use Let's Encrypt or commercial CA
   - Configure proper DNS
   - Enable HSTS

2. **High Availability**
   - Deploy 3+ replicas
   - Use external database
   - Configure pod anti-affinity

3. **Authentication**
   - Integrate with corporate IdP
   - Enable MFA
   - Configure session timeout

4. **Network Security**
   - Implement network policies
   - Use private endpoints
   - Configure firewall rules

5. **Backup & Recovery**
   - Regular etcd backups
   - Disaster recovery plan
   - Test restore procedures

## Integration with GKE

Rancher automatically discovers and manages the GKE cluster features:

- **Workload Identity**: Supported for pod authentication
- **Cloud Logging**: View GKE logs in Rancher
- **Cloud Monitoring**: Metrics available in UI
- **GKE Autopilot**: Compatible (if enabled)
- **Binary Authorization**: Policy management

## Useful Commands

```bash
# Get Rancher version
kubectl get deployment -n cattle-system rancher -o jsonpath='{.spec.template.spec.containers[0].image}'

# List all Rancher resources
kubectl get all -n cattle-system

# Check Rancher webhook
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations

# View Rancher settings
kubectl get settings.management.cattle.io -n cattle-system

# Check cluster status in Rancher
kubectl get clusters.management.cattle.io

# View Rancher managed apps
kubectl get apps.catalog.cattle.io -A
```

## Upgrading Rancher

To upgrade Rancher to a new version:

```bash
# Update Helm repository
helm repo update

# Check available versions
helm search repo rancher-latest/rancher --versions

# Upgrade Rancher
helm upgrade rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.local \
  --set bootstrapPassword=admin \
  --version=<NEW_VERSION>
```

## Uninstalling Rancher

To remove Rancher while keeping the cluster:

```bash
# Uninstall Helm release
helm uninstall rancher -n cattle-system

# Remove namespace
kubectl delete namespace cattle-system

# Clean up CRDs (optional)
kubectl get crd | grep cattle.io | awk '{print $1}' | xargs kubectl delete crd

# Remove webhook configurations
kubectl delete validatingwebhookconfigurations rancher-webhook
kubectl delete mutatingwebhookconfigurations rancher-webhook
```

## Additional Resources

- [Official Rancher Documentation](https://rancher.com/docs/)
- [Rancher GitHub Repository](https://github.com/rancher/rancher)
- [Rancher Community Forums](https://forums.rancher.com/)
- [Rancher Slack Channel](https://slack.rancher.io/)