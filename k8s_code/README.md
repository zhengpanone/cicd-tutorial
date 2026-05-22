# MicroK8s 证书重置、Dashboard 部署与管理指南
## 刷新根CA和服务器证书
```bash
# 1. 停止 MicroK8s
sudo microk8s stop

# 2. 刷新根CA和所有衍生证书（关键步骤）
sudo microk8s refresh-certs --cert ca.crt

# 3. 重新启动 MicroK8s
sudo microk8s start

# 4. 等待完全启动（约30-60秒）
sleep 60

# 5. 检查状态
sudo microk8s status --wait-ready
```

## Dashboard 部署步骤
```bash
# 1. 启用 Dashboard 插件
sudo microk8s enable dashboard

# 2. 等待 Dashboard 启动
microk8s kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=k8s-app=kubernetes-dashboard \
  --timeout=90s

# 3. 获取访问地址
echo "Dashboard URL: https://$(hostname -I | awk '{print $1}'):10443"
```

## 获取访问 Token

```bash
# 1. 查找 Token Secret
kubectl get secret -n kube-system | grep -E "(dashboard|admin).*token"

# 2. 获取 Token（选择一种方法）

# 方法A：查看完整信息
kubectl describe secret -n kube-system microk8s-dashboard-token

# 方法B：直接解码获取Token
kubectl get secret -n kube-system microk8s-dashboard-token \
  -o jsonpath='{.data.token}' | base64 -d

# 3. 复制输出的Token（以eyJ开头的一长串字符串）
```

## 获取 Token

```bash
# 1. 创建一个专门用于 Dashboard 的服务账户
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# 2. 为这个账户绑定集群管理员权限（生产环境请缩小权限范围）
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# 3. 获取该账户的 Secret 名称
SECRET_NAME=$(kubectl get secret -n kubernetes-dashboard | grep admin-user-token | awk '{print $1}')

# 4. 解码并查看 Token
kubectl describe secret $SECRET_NAME -n kubernetes-dashboard
```

# 连接测试

## 集群内访问

```bash
# 创建端口转发
kubectl port-forward -n kube-system \
  service/kubernetes-dashboard 10443:443 --address 0.0.0.0

# 访问地址：https://localhost:10443
```

## 集群外访问
```bash
# 1. 获取 NodePort
kubectl get svc -n kube-system kubernetes-dashboard

# 2. 获取节点IP
microk8s config | grep server

# 3. 访问格式：https://<节点IP>:<NodePort>
# 示例：https://192.168.0.55:32000
```


# Dashboard 常用操作
```bash
# 查看Dashboard Pod状态
kubectl get pods -n kube-system -l k8s-app=kubernetes-dashboard

# 查看Dashboard Service
kubectl get svc -n kube-system kubernetes-dashboard

# 查看Dashboard日志
kubectl logs -n kube-system -l k8s-app=kubernetes-dashboard

# 重启Dashboard
kubectl rollout restart deployment -n kube-system kubernetes-dashboard
```


# 配置调整
## 修改NodePort端口

```bash
# 修改Dashboard Service为NodePort类型
kubectl patch svc -n kube-system kubernetes-dashboard \
  -p '{"spec": {"type": "NodePort"}}'

# 设置特定NodePort（如32000）
kubectl patch svc -n kube-system kubernetes-dashboard \
  -p '{"spec": {"ports": [{"port": 443, "nodePort": 32000}]}}'
```

## 如果不需要外部访问：删除 NodePort Service

```bash
# 还原为ClusterIP
kubectl patch svc -n kube-system kubernetes-dashboard \
  -p '{"spec": {"type": "ClusterIP"}}'

# 重置NodePort
kubectl patch svc -n kube-system kubernetes-dashboard \
  -p '{"spec": {"ports": [{"port": 443, "nodePort": null}]}}'
```

# 监控检查

```bash
# 1. 检查Dashboard健康状况
curl -k https://localhost:10443/healthz

# 2. 检查证书有效期
sudo microk8s inspect

# 3. 查看系统资源使用
microk8s kubectl top nodes
microk8s kubectl top pods -n kube-system
```

# 资源管理
## 删除资源

```bash
# 强制删除Pod
kubectl delete pod <pod-name> --force --grace-period=0

# 按标签删除资源
kubectl delete pods -l app=rabbitmq
kubectl delete statefulset rabbitmq
kubectl delete pvc -l app=elasticsearch
kubectl delete statefulset elasticsearch
kubectl delete job es-init-permissions

# 清理Dashboard
sudo microk8s disable dashboard
```

## 启动资源
```bash

# 重启部署
kubectl rollout restart deployment/mongodb

# 缩放副本
kubectl scale deployment mongodb --replicas=2

```

# 数据库管理（MongoDB 示例）

```bash

# 1. 获取MongoDB Pod名称
POD=$(kubectl get pod -l app=mongodb -o jsonpath='{.items[0].metadata.name}')

# 2. 创建管理员用户
kubectl exec -it $POD -- mongosh \
  --eval 'db.getSiblingDB("admin").createUser({user:"admin", pwd:"mongodb123456", roles:[{role:"root", db:"admin"}]})'

# 3. 连接数据库
kubectl exec -it deployment/mongodb -- mongosh \
  -u admin -p mongodb123456 --authenticationDatabase admin

# 4. 查看用户
kubectl exec -it $POD -- mongosh \
  --eval 'db.getSiblingDB("admin").getUsers()'

```

# 网络诊断

```bash
# 获取宿主机在Pod网络中的IP
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# 在容器内执行：
#   ip route | grep default
# 或
#   cat /etc/resolv.conf

# 从现有Pod查看网络
kubectl exec -it deployment/prometheus -- sh
# 执行：
#   nslookup kubernetes.default
#   ping <service-name>

```bash
# 方法 2: 从现有 Pod 查看
kubectl exec -it prometheus-599fd854f5-7q8fx -- sh
# 在 Pod 内
ip route | grep default
# 或
cat /etc/resolv.conf


microk8s kubectl exec -it deployment/prometheus -- sh
```


# K3S

## 安装wsl

```bash
wsl --install -d Ubuntu-24.04
```

## 安装卸载
```bash
# 安装
curl -sfL https://get.k3s.io | sh -
# 卸载
sudo /usr/local/bin/k3s-uninstall.sh
```

## 配置 kubectl

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

## 验证k3s

```bash
kubectl get nodes
```


修改 Docker daemon

WSL2 内：

sudo nano /etc/docker/daemon.json

加入：

{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"]
}
✔ 重启 Docker
sudo service docker restart


PowerShell 连接
$env:DOCKER_HOST="tcp://localhost:2375"
docker ps