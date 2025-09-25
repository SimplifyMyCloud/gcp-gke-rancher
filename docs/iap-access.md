# Accessing Rancher via IAP Tunnel

## Overview

For enhanced security, Rancher is configured to be accessible only through an Identity-Aware Proxy (IAP) tunnel. This ensures that only authorized users can access the Rancher management interface, adding an additional layer of security beyond Rancher's built-in authentication.

## Architecture

```
Your Local Machine
        │
        │ IAP Tunnel (SSH)
        ▼
  Bastion Host ──────► GKE Cluster
  (IAP Protected)      (Private IPs)
                           │
                           ▼
                    Rancher Dashboard
                    (NodePort Service)
```

## Prerequisites

1. **IAP Access Configured**: Your email must be in the `allowed_iap_users` list in `terraform/terraform.tfvars`
2. **Google Cloud SDK**: Installed and authenticated
3. **kubectl**: Installed locally (optional, for direct access)

## Access Methods

### Method 1: Direct kubectl Port Forward (Recommended)

This method uses your local kubectl to create a secure tunnel directly to the Rancher service:

```bash
# Create direct port forward to Rancher (requires local kubectl access)
kubectl port-forward -n cattle-system svc/rancher 8443:443
```

**Access Rancher at**: https://localhost:8443

**Note**: This works because your local machine has direct GKE cluster access via authorized networks.

### Method 2: IAP Tunnel (Alternative)

For environments without direct cluster access, use IAP tunnel through bastion:

```bash
# Create IAP tunnel through bastion to Rancher
gcloud compute ssh poc-bastion \
  --zone=us-west1-a \
  --tunnel-through-iap \
  --project=simplifymycloud-dev \
  --command="kubectl port-forward -n cattle-system svc/rancher 8443:443 --address=0.0.0.0" \
  -- -L 8443:localhost:8443
```

**Access Rancher at**: https://localhost:8443

### Method 3: SOCKS Proxy (Full Browser Access)

This method routes all browser traffic through the bastion:

```bash
# Step 1: Create SOCKS proxy through IAP
gcloud compute ssh poc-bastion \
  --zone=us-west1-a \
  --tunnel-through-iap \
  --project=simplifymycloud-dev \
  -- -N -D 1080 -f

# Step 2: Configure browser to use SOCKS proxy
# Firefox: Settings → Network Settings → Manual proxy → SOCKS Host: localhost, Port: 1080
# Chrome: Use extension like "Proxy SwitchyOmega" or launch with:
google-chrome --proxy-server="socks5://localhost:1080"
```

**Access Rancher at**: https://rancher.cattle-system.svc.cluster.local

### Method 4: SSH Tunnel with NodePort

Use the NodePort directly through the bastion:

```bash
# Get the NodePort for Rancher HTTPS
NODEPORT=$(gcloud compute ssh poc-bastion \
  --zone=us-west1-a \
  --tunnel-through-iap \
  --project=simplifymycloud-dev \
  --command="kubectl get svc rancher -n cattle-system -o jsonpath='{.spec.ports[?(@.name==\"https\")].nodePort}'")

echo "Rancher NodePort: $NODEPORT"

# Get a node IP
NODE_IP=$(gcloud compute ssh poc-bastion \
  --zone=us-west1-a \
  --tunnel-through-iap \
  --project=simplifymycloud-dev \
  --command="kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}'")

echo "Node IP: $NODE_IP"

# Create tunnel to NodePort
gcloud compute ssh poc-bastion \
  --zone=us-west1-a \
  --tunnel-through-iap \
  --project=simplifymycloud-dev \
  -- -L 8443:${NODE_IP}:${NODEPORT} -N -f
```

**Access Rancher at**: https://localhost:8443

## One-Line Access Scripts

### Quick Access Script (save as `rancher-tunnel.sh`)

```bash
#!/bin/bash

echo "Creating secure tunnel to Rancher..."

# Kill existing port forwards on 8443
lsof -ti:8443 | xargs kill -9 2>/dev/null

# Create new tunnel
kubectl port-forward -n cattle-system svc/rancher 8443:443 &

echo "Waiting for tunnel to establish..."
sleep 3

echo "Rancher available at: https://localhost:8443"
echo "Username: admin"
echo "Password: admin"
echo ""
echo "Press Ctrl+C to close tunnel"

wait
```

### Persistent Tunnel with Auto-Reconnect

```bash
#!/bin/bash

while true; do
  echo "Establishing Rancher tunnel..."
  kubectl port-forward -n cattle-system svc/rancher 8443:443

  echo "Tunnel disconnected. Reconnecting in 5 seconds..."
  sleep 5
done
```

## Managing Tunnels

### Check Active Tunnels

```bash
# List all SSH tunnels
ps aux | grep -E "ssh.*tunnel-through-iap"

# List port forwards
lsof -i :8443
```

### Kill Existing Tunnels

```bash
# Kill all IAP tunnels
pkill -f "tunnel-through-iap"

# Kill specific port forward
lsof -ti:8443 | xargs kill -9
```

## Troubleshooting

### Issue: Permission Denied

**Solution**: Ensure your email is in `allowed_iap_users`:

```bash
# Check current IAP users
terraform output -state=terraform/terraform.tfstate allowed_iap_users

# Add your user
echo 'allowed_iap_users = ["user:your-email@domain.com"]' >> terraform/terraform.tfvars
cd terraform && terraform apply
```

### Issue: Connection Refused on localhost:8443

**Solution**: Check if tunnel is active:

```bash
# Verify tunnel process
ps aux | grep 8443

# Test connection
curl -k https://localhost:8443
```

### Issue: Certificate Warnings

**Expected**: Rancher uses self-signed certificates in this POC setup. Click "Advanced" → "Proceed" in your browser.

### Issue: Rancher Not Responding

**Solution**: Check Rancher pod status from bastion:

```bash
gcloud compute ssh poc-bastion \
  --zone=us-west1-a \
  --tunnel-through-iap \
  --project=simplifymycloud-dev \
  --command="kubectl get pods -n cattle-system"
```

## Security Benefits

### Why IAP Tunnel?

1. **No Public Exposure**: Rancher is not accessible from the internet
2. **Identity Verification**: IAP requires Google account authentication
3. **Audit Logging**: All access is logged in Cloud Audit Logs
4. **Zero Trust**: No VPN required, works from anywhere
5. **Granular Access**: Per-user access control

### Defense in Depth

```
Layer 1: IAP Authentication (Google Identity)
    ↓
Layer 2: SSH Key Authentication (Bastion Access)
    ↓
Layer 3: Kubernetes RBAC (Service Access)
    ↓
Layer 4: Rancher Authentication (Application Access)
```

## Best Practices

1. **Use Dedicated Terminal**: Keep tunnel terminal separate from work terminal
2. **Script Access**: Create aliases for common tunnels
3. **Monitor Access**: Review IAP logs regularly
4. **Rotate Credentials**: Change Rancher password from default
5. **Limit IAP Users**: Only add necessary users to `allowed_iap_users`

## Alternative: Direct kubectl Access

If you only need kubectl access (not Rancher UI):

```bash
# Get cluster credentials
gcloud container clusters get-credentials gke-rancher-testdrive \
  --zone=us-west1-a \
  --project=simplifymycloud-dev

# Create kubectl tunnel through bastion
gcloud compute ssh poc-bastion \
  --zone=us-west1-a \
  --tunnel-through-iap \
  --project=simplifymycloud-dev \
  -- -L 8443:127.0.0.1:6443 -N -f

# Update kubeconfig to use tunnel
kubectl config set-cluster gke-rancher-testdrive \
  --server=https://127.0.0.1:8443

# Now kubectl works through the secure tunnel
kubectl get nodes
```

## Quick Reference

| Access Method | Command | URL |
|--------------|---------|-----|
| Port Forward | `gcloud compute ssh poc-bastion --tunnel-through-iap -- -L 8443:localhost:8443` | https://localhost:8443 |
| SOCKS Proxy | `gcloud compute ssh poc-bastion --tunnel-through-iap -- -N -D 1080` | https://rancher.cattle-system.svc.cluster.local |
| NodePort | Use node IP and NodePort through tunnel | https://localhost:8443 |

## Summary

By placing Rancher behind IAP:
- ✅ **No public internet exposure**
- ✅ **Google identity verification required**
- ✅ **Full audit trail of access**
- ✅ **No VPN infrastructure needed**
- ✅ **Works from any location**

The minor inconvenience of establishing a tunnel is offset by the significant security improvements and compliance benefits.