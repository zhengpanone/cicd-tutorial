# Kong Gateway on Kubernetes

This directory contains a local-development Kong Gateway manifest for Kubernetes.
It reuses the existing PostgreSQL service from `k8s_code/postgres/postgres-k8s.yml`
instead of creating a second database instance.

## Resources

`kong-k8s.yaml` includes:

- `Secret`: stores Kong PostgreSQL connection settings
- `Job`: `kong-db-init`, creates the `kong` database if it does not exist
- `Job`: `kong-migrations`, runs Kong bootstrap or upgrade migrations
- `Deployment`: `kong`, runs `kong:3.5`
- `Service`: `kong-proxy`, in-cluster proxy access
- `Service`: `kong-admin`, in-cluster Admin API access
- `Service`: `kong-nodeport`, local NodePort access for proxy and Admin API

## Assumptions

- PostgreSQL is already deployed in the `default` namespace
- PostgreSQL service name is `postgres-service`
- PostgreSQL credentials are `postgres / postgres`
- The PostgreSQL pod is reachable before Kong is applied

If your PostgreSQL service name or password is different, update
`k8s_code/kong/kong-k8s.yaml` before deployment.

## Deploy

```bash
# 1. Confirm PostgreSQL is ready
kubectl get pods -l app=postgres
kubectl get svc postgres-service

# 2. Apply Kong resources
kubectl apply -f kong-k8s.yaml

# 3. Watch the init and migration jobs
kubectl get jobs -l app=kong
kubectl logs job/kong-db-init
kubectl logs job/kong-migrations

# 4. Wait for Kong to become ready
kubectl rollout status deployment/kong -n default --timeout=180s
kubectl get pods -l app=kong
```

## Access

Local NodePort access:

```text
Proxy HTTP:  http://localhost:30000
Proxy HTTPS: https://localhost:30444
Admin API:   http://localhost:30001
```

In-cluster service access:

```text
Proxy HTTP:  http://kong-proxy.default.svc.cluster.local:8000
Proxy HTTPS: https://kong-proxy.default.svc.cluster.local:8443
Admin API:   http://kong-admin.default.svc.cluster.local:8001
```

## Verify

Check Kong status:

```bash
curl http://localhost:30001/status
curl http://localhost:30001/services
```

Create a sample service and route:

```bash
curl -i -X POST http://localhost:30001/services \
  --data name=example-service \
  --data url=http://httpbin.org

curl -i -X POST http://localhost:30001/services/example-service/routes \
  --data 'paths[]=/example'
```

Then verify traffic through Kong:

```bash
curl http://localhost:30000/example/get
```

## Operations

Useful commands:

```bash
# Kong logs
kubectl logs deployment/kong -n default --tail=100

# Restart Kong
kubectl rollout restart deployment/kong -n default

# Re-run database jobs
kubectl delete job kong-db-init kong-migrations -n default
kubectl apply -f kong-k8s.yaml
```

## Notes

- This manifest focuses on Kong Gateway itself and reuses the existing PostgreSQL.
- The Admin API is exposed through NodePort for local development convenience.
- For a production cluster, keep the Admin API internal-only or protect it with
  network policy, ingress auth, or a VPN.

## Cleanup

```bash
kubectl delete -f kong-k8s.yaml
```
