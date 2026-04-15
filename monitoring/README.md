# Platform Monitoring Setup

All monitoring is centralised — one Prometheus + Grafana instance for 100+ apps.
Each app is automatically discovered via Kubernetes labels applied by the Helm chart.

## Install Gateway API CRDs & ALB Controller

```bash
# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# Install ALB Controller (Application Gateway for Containers)
helm install alb-controller \
  oci://mcr.microsoft.com/application-lb/charts/alb-controller \
  --namespace azure-alb-system --create-namespace \
  --version 1.3.7 \
  --set albController.namespace=azure-alb-system \
  --set albController.podIdentity.clientID="<ALB_CONTROLLER_IDENTITY_CLIENT_ID>"

# Deploy shared Gateway
kubectl create namespace gateway-system
kubectl apply -f ../platform/gateway/gateway.yaml
```

## Install OPA Gatekeeper

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update

helm install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system --create-namespace

# Apply platform policies
kubectl apply -f ../platform/policies/
```

## Install Prometheus & Grafana (kube-prometheus-stack)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values.yaml
```

## Import Grafana Dashboard

1. Port-forward to Grafana:

   ```bash
   kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
   ```

2. Open `http://localhost:3000` (default login: admin / prom-operator)
3. Go to **Dashboards > Import** and upload `grafana-dashboard.json`
4. Use the **namespace** and **team** dropdowns to filter by app or team

## Azure Monitor Integration

The AKS cluster is provisioned with OMS agent enabled, which sends:

- Container logs to Log Analytics
- Kubernetes metrics to Azure Monitor

View in the Azure Portal:

- **AKS cluster > Monitoring > Insights** for live metrics
- **AKS cluster > Monitoring > Logs** for KQL queries

### Useful KQL Queries

**Errors across all apps:**

```kql
ContainerLogV2
| where LogMessage contains "error" or LogMessage contains "exception"
| summarize ErrorCount = count() by ContainerName, bin(TimeGenerated, 5m)
| order by ErrorCount desc
| take 50
```

**Pod restarts by namespace:**

```kql
KubeEvents
| where Reason == "BackOff" or Reason == "Unhealthy"
| summarize Count = count() by Namespace, Name, Reason
| order by Count desc
```

**Resource usage per namespace:**

```kql
Perf
| where ObjectName == "K8SContainer"
| where CounterName == "cpuUsageNanoCores" or CounterName == "memoryWorkingSetBytes"
| summarize avg(CounterValue) by InstanceName, CounterName, bin(TimeGenerated, 5m)
```

| take 50
