# 部署步骤
```bash
# 1. 部署 PV/PVC/ConfigMap/Secret/Services/Job
kubectl apply -f k8s_code/consul/

# 2. 删除旧 StatefulSet（保留 PVC）
kubectl delete statefulset consul

kubectl delete job consul-bootstrap

# 3. 创建新的 StatefulSet
kubectl apply -f k8s_code/consul/

# 4. 等待 Pod 就绪
kubectl rollout status statefulset/consul

# 列出 Pod
kubectl get pods -l app=consul

# 查看日志
kubectl logs consul-0

```

# 生成自签名证书

```bash
# 生成自签名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=consul.local"
kubectl create secret tls consul-ui-tls --cert=tls.crt --key=tls.key -n default

cat tls.crt | base64 -w 0
cat tls.key | base64 -w 0
```