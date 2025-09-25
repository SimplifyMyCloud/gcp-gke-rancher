# GKE Stats Test Website

## Overview

The test website is a demonstration application that showcases the GKE cluster's capabilities while providing real-time statistics and metrics. It consists of a React-style frontend and a Node.js backend that queries the Kubernetes API.

## Architecture

```
┌──────────────────────────────────────┐
│          Internet Users              │
└────────────────┬─────────────────────┘
                 │
         ┌───────▼────────┐
         │ Load Balancer  │
         │  (Public IP)   │
         └───────┬────────┘
                 │
    ┌────────────▼──────────────┐
    │    NGINX Frontend         │
    │  (Static HTML + Assets)   │
    └────────────┬──────────────┘
                 │ /api/*
    ┌────────────▼──────────────┐
    │    Node.js Backend        │
    │  (Kubernetes API Client)  │
    └────────────┬──────────────┘
                 │
    ┌────────────▼──────────────┐
    │    Kubernetes API         │
    │  (Cluster Statistics)     │
    └───────────────────────────┘
```

## Components

### Frontend (index.html)

**Technology Stack**:
- Pure HTML5/CSS3/JavaScript
- No framework dependencies
- Responsive design
- Auto-refreshing statistics

**Features**:
- Real-time cluster statistics
- Visual metric cards
- Gradient UI design
- Mobile-responsive layout
- Auto-updating timestamp

**Key Metrics Displayed**:
1. Total Nodes
2. Running Pods
3. Active Services
4. CPU Usage
5. Memory Usage
6. Namespace Count
7. Kubernetes Version
8. Cluster Information

### Backend (backend.js)

**Technology Stack**:
- Node.js 18
- @kubernetes/client-node
- Native HTTP server

**Endpoints**:
- `GET /api/stats` - Returns cluster statistics
- `GET /health` - Health check endpoint

**Permissions Required**:
```yaml
rules:
- apiGroups: [""]
  resources: ["nodes", "pods", "services", "namespaces"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
  verbs: ["get", "list"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]
```

## Deployment Configuration

### Kubernetes Resources

The website is deployed with the following resources:

1. **Namespace**: `gke-stats`
2. **ServiceAccount**: `stats-backend-sa`
3. **ClusterRole**: `cluster-stats-reader`
4. **ClusterRoleBinding**: `stats-backend-binding`
5. **Deployments**:
   - `stats-backend` (2 replicas)
   - `stats-frontend` (2 replicas)
6. **Services**:
   - `backend-service` (ClusterIP)
   - `frontend-service` (LoadBalancer)
7. **Ingress**: `stats-ingress`
8. **ManagedCertificate**: `gke-stats-cert`

### Container Images

Built and stored in Google Artifact Registry:
- Frontend: `us-west1-docker.pkg.dev/simplifymycloud-dev/gke-stats/frontend:latest`
- Backend: `us-west1-docker.pkg.dev/simplifymycloud-dev/gke-stats/backend:latest`

## Building & Deployment

### Building Images Locally

```bash
cd k8s/website

# Build frontend
docker build -f Dockerfile --target frontend -t gke-stats-frontend:latest .

# Build backend
docker build -f Dockerfile --target backend -t gke-stats-backend:latest .
```

### Pushing to Registry

```bash
# Configure Docker authentication
gcloud auth configure-docker us-west1-docker.pkg.dev

# Tag images
docker tag gke-stats-frontend:latest \
  us-west1-docker.pkg.dev/simplifymycloud-dev/gke-stats/frontend:latest

docker tag gke-stats-backend:latest \
  us-west1-docker.pkg.dev/simplifymycloud-dev/gke-stats/backend:latest

# Push images
docker push us-west1-docker.pkg.dev/simplifymycloud-dev/gke-stats/frontend:latest
docker push us-west1-docker.pkg.dev/simplifymycloud-dev/gke-stats/backend:latest
```

### Deploying to GKE

```bash
# Apply all resources
kubectl apply -f k8s/website/deployment.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=stats-frontend -n gke-stats --timeout=300s
kubectl wait --for=condition=ready pod -l app=stats-backend -n gke-stats --timeout=300s

# Get Load Balancer IP
kubectl get svc -n gke-stats frontend-service
```

## Configuration

### Environment Variables

Backend service environment variables:
```yaml
env:
- name: CLUSTER_NAME
  value: "gke-rancher-testdrive"
- name: PORT
  value: "3000"
```

### Resource Limits

**Backend**:
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

**Frontend**:
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"
```

### Health Checks

Both services include liveness and readiness probes:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: <service-port>
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: <service-port>
  initialDelaySeconds: 5
  periodSeconds: 5
```

## Access & Testing

### Public Access

Once deployed, the website is accessible via the Load Balancer:

```bash
# Get the external IP
EXTERNAL_IP=$(kubectl get svc -n gke-stats frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Website URL: http://${EXTERNAL_IP}"
```

### Local Testing

To test locally with port forwarding:

```bash
# Forward frontend
kubectl port-forward -n gke-stats svc/frontend-service 8080:80

# Forward backend (in another terminal)
kubectl port-forward -n gke-stats svc/backend-service 3000:3000

# Access at http://localhost:8080
```

### API Testing

Test the backend API directly:

```bash
# From within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://backend-service.gke-stats.svc.cluster.local:3000/api/stats

# Via port-forward
kubectl port-forward -n gke-stats svc/backend-service 3000:3000
curl http://localhost:3000/api/stats | jq
```

## Monitoring

### View Logs

```bash
# Frontend logs
kubectl logs -n gke-stats -l app=stats-frontend --tail=50

# Backend logs
kubectl logs -n gke-stats -l app=stats-backend --tail=50

# Follow logs
kubectl logs -n gke-stats -l app=stats-backend -f
```

### Check Metrics

```bash
# Pod resource usage
kubectl top pods -n gke-stats

# Service endpoints
kubectl get endpoints -n gke-stats

# Events
kubectl get events -n gke-stats --sort-by='.lastTimestamp'
```

### Debug Issues

```bash
# Describe pods for issues
kubectl describe pod -n gke-stats -l app=stats-backend

# Check service configuration
kubectl get svc -n gke-stats -o yaml

# Verify RBAC permissions
kubectl auth can-i list nodes --as=system:serviceaccount:gke-stats:stats-backend-sa
```

## Customization

### Modify Frontend Design

Edit `k8s/website/index.html`:
1. Update CSS styles in `<style>` section
2. Modify HTML structure in `<body>`
3. Adjust JavaScript for new metrics

### Add New Metrics

1. **Backend** - Edit `backend.js`:
   ```javascript
   // Add new metric collection
   const configMaps = await k8sApi.listConfigMapForAllNamespaces();
   stats.configMapCount = configMaps.body.items.length;
   ```

2. **Frontend** - Update `index.html`:
   ```html
   <!-- Add new card -->
   <div class="stat-card">
       <div class="stat-value" id="configMapCount">-</div>
       <div class="stat-title">ConfigMaps</div>
   </div>
   ```

   ```javascript
   // Update display
   document.getElementById('configMapCount').textContent = data.configMapCount;
   ```

### Change Refresh Interval

Edit `index.html`:
```javascript
// Change from 30 seconds to 60 seconds
setInterval(fetchClusterStats, 60000);
```

### Custom Domain

To use a custom domain:

1. **Reserve static IP**:
   ```bash
   gcloud compute addresses create gke-stats-ip --global
   ```

2. **Update Ingress**:
   ```yaml
   metadata:
     annotations:
       kubernetes.io/ingress.global-static-ip-name: "gke-stats-ip"
   ```

3. **Configure DNS**:
   Point your domain to the static IP

4. **Update ManagedCertificate**:
   ```yaml
   spec:
     domains:
       - your-domain.com
   ```

## Troubleshooting

### Website Not Loading

1. **Check Load Balancer**:
   ```bash
   kubectl get svc -n gke-stats frontend-service
   # Ensure EXTERNAL-IP is assigned
   ```

2. **Verify pods are running**:
   ```bash
   kubectl get pods -n gke-stats
   ```

3. **Check firewall rules**:
   ```bash
   gcloud compute firewall-rules list | grep health-check
   ```

### API Errors

1. **Check backend logs**:
   ```bash
   kubectl logs -n gke-stats -l app=stats-backend --tail=100
   ```

2. **Verify RBAC**:
   ```bash
   kubectl describe clusterrolebinding stats-backend-binding
   ```

3. **Test service connectivity**:
   ```bash
   kubectl exec -n gke-stats deploy/stats-frontend -- wget -O- http://backend-service:3000/api/stats
   ```

### Incorrect Statistics

1. **Check metrics-server**:
   ```bash
   kubectl get deploy -n kube-system metrics-server
   ```

2. **Verify API permissions**:
   ```bash
   kubectl auth can-i list pods --as=system:serviceaccount:gke-stats:stats-backend-sa
   ```

3. **Test API directly**:
   ```bash
   kubectl exec -n gke-stats deploy/stats-backend -- node -e "console.log('API test')"
   ```

## Performance Optimization

### Frontend Optimization

1. **Enable compression** in nginx.conf:
   ```nginx
   gzip on;
   gzip_types text/html text/css application/javascript;
   ```

2. **Add caching headers**:
   ```nginx
   location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
       expires 1h;
       add_header Cache-Control "public, immutable";
   }
   ```

### Backend Optimization

1. **Implement caching**:
   ```javascript
   let cache = {};
   let cacheTime = 0;
   const CACHE_TTL = 10000; // 10 seconds

   if (Date.now() - cacheTime < CACHE_TTL) {
       return cache;
   }
   ```

2. **Use connection pooling** for Kubernetes API

### Scaling

For high traffic:
```bash
# Scale frontend
kubectl scale deployment -n gke-stats stats-frontend --replicas=5

# Scale backend
kubectl scale deployment -n gke-stats stats-backend --replicas=3

# Enable HPA
kubectl autoscale deployment -n gke-stats stats-frontend --min=2 --max=10 --cpu-percent=70
```

## Security Considerations

### Current Setup (POC)

- Public LoadBalancer exposure
- Read-only Kubernetes API access
- No authentication on website
- Self-contained in namespace

### Production Recommendations

1. **Add Authentication**:
   - OAuth2 proxy
   - IAP for website
   - API key for backend

2. **Network Security**:
   - NetworkPolicies
   - Private LoadBalancer
   - WAF rules

3. **API Security**:
   - Rate limiting
   - CORS configuration
   - Input validation

4. **Secrets Management**:
   - Use Secret Manager
   - Rotate credentials
   - Encrypt at rest

## Uninstalling

To remove the test website:

```bash
# Delete all resources
kubectl delete namespace gke-stats

# Delete container images (optional)
gcloud artifacts repositories delete gke-stats \
  --location=us-west1 \
  --quiet

# Remove firewall rules (if custom)
gcloud compute firewall-rules delete gke-stats-allow-http \
  --quiet
```

## Future Enhancements

### Planned Features

1. **Historical Data**:
   - Time-series graphs
   - Prometheus integration
   - Data persistence

2. **Interactive Features**:
   - Pod management
   - Log viewing
   - Shell access

3. **Advanced Metrics**:
   - Cost tracking
   - Performance analysis
   - Capacity planning

4. **UI Improvements**:
   - Dark mode
   - Custom themes
   - Mobile app

### Integration Options

- **Grafana**: Rich visualizations
- **Prometheus**: Metrics collection
- **Elasticsearch**: Log aggregation
- **Jaeger**: Distributed tracing

## Support & Resources

- [Kubernetes Dashboard Docs](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
- [Node.js Kubernetes Client](https://github.com/kubernetes-client/javascript)
- [GKE Ingress Docs](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress)
- [NGINX Configuration](https://nginx.org/en/docs/)