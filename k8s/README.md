# Kubernetes/OpenShift Deployment

Simplified Kubernetes descriptors to deploy the Task Management API on OpenShift.

## Files

- `namespace.yaml` - Namespace `tasks`
- `configmap.yaml` - Application configuration
- `secret.yaml` - Database credentials
- `deployment.yaml` - API deployment (2 replicas, SCC restricted compatible)
- `service.yaml` - ClusterIP service
- `route.yaml` - OpenShift Route with TLS

## Prerequisites

- OpenShift/Kubernetes cluster
- PostgreSQL database accessible
- Docker image built and available

## Deployment

1. **Update secret with your DB credentials**:
   ```bash
   vi secret.yaml
   # Update: DATABASE_URL: "postgresql://user:pass@host:5432/db"
   ```

2. **Deploy resources**:
   ```bash
   oc apply -f namespace.yaml
   oc apply -f configmap.yaml
   oc apply -f secret.yaml
   oc apply -f deployment.yaml
   oc apply -f service.yaml
   oc apply -f route.yaml
   ```

   Or in one command:
   ```bash
   oc apply -f .
   ```

## Verification

```bash
# Check pods
oc get pods -n tasks

# Get route URL
oc get route task-management -n tasks

# Test API
ROUTE=$(oc get route task-management -n tasks -o jsonpath='{.spec.host}')
curl https://$ROUTE/
```

## Logs

```bash
oc logs -l app=task-management -n tasks -f
```

## Cleanup

```bash
oc delete -f .
# or
oc delete namespace tasks
```

## Notes

- Deployment is compatible with OpenShift SCC `restricted`
- TLS is handled by OpenShift Route (edge termination)
- Database must be deployed separately and accessible from the cluster
