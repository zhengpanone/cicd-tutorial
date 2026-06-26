#!/bin/bash
# deploy-emqx.sh

# 1. 创建命名空间
kubectl apply -f 0-namespace.yaml

# 2. 创建 PV
kubectl apply -f 1-pv.yaml

# 3. 创建 Secret
kubectl create secret generic emqx-secret \
  -n emqx \
  --from-literal=cookie=emqx_cluster_cookie_$(openssl rand -hex 8) \
  --from-literal=api-key=$(openssl rand -hex 16)

# 4. 创建 PVC
kubectl apply -f 2-pvc.yaml

# 5. 创建 ConfigMap
kubectl apply -f 3-configmap.yaml

# 6. 创建 Deployment
kubectl apply -f 4-deployment.yaml

# 7. 创建 Service
kubectl apply -f 5-service.yaml

# 8. 验证部署
echo "等待 EMQX Pod 启动..."
kubectl wait --namespace=emqx --for=condition=ready pod --selector=app=emqx --timeout=300s

echo "EMQX 集群状态:"
kubectl exec -n emqx deployment/emqx -- emqx ctl cluster status

echo ""
echo "访问信息:"
echo "Dashboard: http://$(kubectl get node -o jsonpath='{.items[0].status.addresses[0].address}'):38084"
echo "MQTT TCP: $(kubectl get node -o jsonpath='{.items[0].status.addresses[0].address}'):31883"
echo "MQTT WebSocket: ws://$(kubectl get node -o jsonpath='{.items[0].status.addresses[0].address}'):38083"
echo ""
echo "默认账号: admin / public"