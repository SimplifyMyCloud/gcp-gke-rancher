#!/bin/bash

set -e

echo "Installing Rancher on GKE cluster..."

# Install NGINX Ingress Controller
echo "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

echo "Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=300s

# Install cert-manager
echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s 2>/dev/null || \
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=300s

# Add Rancher Helm repository
echo "Adding Rancher Helm repository..."
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

# Create cattle-system namespace
kubectl create namespace cattle-system || true

# Install Rancher
echo "Installing Rancher..."
helm upgrade --install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --create-namespace \
  --set hostname=rancher.local \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=secret \
  --set replicas=1 \
  --wait --timeout=10m

# Create self-signed certificate
kubectl -n cattle-system create secret tls tls-rancher-ingress \
  --cert=/dev/stdin --key=/dev/stdin <<EOF
-----BEGIN CERTIFICATE-----
MIIDKzCCAhOgAwIBAgIUa2V5c2VsZmdlbmVyYXRlZDExMDAwDQYJKoZIhvcNAQEL
BQAwJTEjMCEGA1UEAwwacmFuY2hlci5sb2NhbCwqLnJhbmNoZXIubG9jYWwwHhcN
MjQwMjA2MTEzMDAwWhcNMzQwMjAzMTEzMDAwWjAlMSMwIQYDVQQDDBpyYW5jaGVy
LmxvY2FsLCoucmFuY2hlci5sb2NhbDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
AQoCggEBAL3WrPCbPbPxYt9Qd9Mn9+OIp91RZcH8fM63PW6qX2zVABfHhPDpIVrP
qB9xPPeJFNJKOuF6o/f7oiM77yxbsSrhDOENRuq6Fi8PDZrK62CxN3gE4EQB99cc
PTRbQUKhktA4wBQGL76oh35XFD4DIqvdK3LPqld9pCfMLAx7WI4tIz1UjcnBFnvQ
Si8RFS98TbFbz2UKxgxeiALoP4pLg0IiPX8H4YG663LteVadAiPm/pe34KXa79AP
QoEUfQWlounhTHf9uCoIEbwqQzgXhq2LoSGlg12mdFdW1af/BtY0uHQxYJGDdTQB
SmTnA3S1xF7gsTWqf4hshmrkJR5VoQsCAwEAAaNVMFMwUQYDVR0RBEowSIIYcmFu
Y2hlci5xdWlja2xvY2FsLmlvghFyYW5jaGVyLmxvY2Fsgg8qLnJhbmNoZXIubG9j
YWyHBH8AAAGHBAoAAAEwDQYJKoZIhvcNAQELBQADggEBAFs8dHCYOkPrB10nN7/h
+BrulTL7lRf/6j4ypXO/YOmZ1574aOYQJGhLtJfMaLBDBntFDbaLbQnyrvGDn6VT
dZXC0pGyPe4/hG8nFjBwBuilding8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
-----END CERTIFICATE-----
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC91qzwmz2z8WLf
UHfTJ/fjiKfdUWXB/HzOtz1uql9s1QAXx4Tw6SFaz6gfcTz3iRTSSjrheqP3+6Ij
O+8sW7Eq4QzhDUbquhYvDw2ayutgsTd4BOBEA
-----END PRIVATE KEY-----
EOF

echo ""
echo "Rancher installation complete!"
echo ""
echo "To access Rancher:"
echo "1. Get the NGINX Ingress Controller external IP:"
echo "   kubectl get svc -n ingress-nginx ingress-nginx-controller"
echo ""
echo "2. Add the IP to your /etc/hosts file:"
echo "   <EXTERNAL_IP> rancher.local"
echo ""
echo "3. Access Rancher at: https://rancher.local"
echo "   Initial password: admin"
echo ""