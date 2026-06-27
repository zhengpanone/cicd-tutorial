# Headlamp on Kubernetes

Headlamp 是 K8s 官方推荐的 Kubernetes Dashboard 替代品，由 [kubernetes-sigs](https://github.com/kubernetes-sigs/headlamp) 维护。界面更现代，功能更丰富，Token 认证兼容 K8s 1.24+。本目录提供在 Docker Desktop Kubernetes 上的部署清单，替代已归档的 kubernetes-dashboard 项目。

## 资源说明

| 资源类型 | 名称 | 说明 |
|---|---|---|
| ServiceAccount | headlamp-admin | 管理员身份 |
| ClusterRoleBinding | headlamp-admin | 绑定 cluster-admin 角色 |
| Deployment | headlamp | Headlamp latest（in-cluster 模式） |
| Service (ClusterIP) | headlamp | 集群内部通信，端口 80 → 4466 |
| Service (NodePort) | headlamp-nodeport | 外部访问，端口 30443 |

## 前置条件

1. **kubernetes-dashboard 命名空间**已创建（Dashboard 官方 manifest 会创建）
2. **Kubernetes 上下文**：确认当前上下文为 docker-desktop

```bash
kubectl config current-context
```

## 部署

```bash
# 部署 Headlamp
kubectl apply -f headlamp-k8s.yaml

# 等待 Pod 就绪
kubectl rollout status deployment/headlamp -n kubernetes-dashboard --timeout=120s

# 检查状态
kubectl get pods -n kubernetes-dashboard -l app=headlamp
```

预期输出：

```text
NAME                        READY   STATUS    RESTARTS   AGE
headlamp-xxx                1/1     Running   0          60s
```

## 获取登录 Token

```bash
# 生成长期 Token（1 年有效，推荐）
kubectl create token headlamp-admin -n kubernetes-dashboard --duration=8760h
```

复制输出的 Token，在 Headlamp 登录页面粘贴即可。

## 访问 Headlamp

| 方式 | URL |
|---|---|
| Ingress HTTP | http://headlamp.k8s:18080 |
| Ingress HTTPS | https://headlamp.k8s:18443 |
| NodePort | http://localhost:30443 |

需先在 hosts 文件添加 `127.0.0.1 headlamp.k8s`。

## 常用运维命令

```bash
# 查看日志
kubectl logs -n kubernetes-dashboard deployment/headlamp --tail=50

# 重启
kubectl rollout restart deployment/headlamp -n kubernetes-dashboard

# 进入容器
kubectl exec -it $(kubectl get pod -n kubernetes-dashboard -l app=headlamp -o name) -n kubernetes-dashboard -- sh
```

## 常见问题

### 镜像拉取失败

ghcr.io 在国内可能访问不畅，可通过 Docker daemon.json 配置镜像代理或手动拉取后 `docker tag` 到本地。

### Token 登录后显示 "Error authenticating"

Headlamp 的 `/me` 端点默认从 JWT 的 OIDC 字段（`preferred_username`、`name` 等）提取用户名，但 K8s ServiceAccount Token 不含这些字段，只有 `sub`。部署时已通过 `-me-username-path=sub` 参数解决。如自行部署需确保加上此参数。

### Token 获取失败

确认 ServiceAccount 和 ClusterRoleBinding 已正确创建：

```bash
kubectl get sa headlamp-admin -n kubernetes-dashboard
kubectl get clusterrolebinding headlamp-admin
```

## 清理资源

```bash
kubectl delete -f headlamp-k8s.yaml
```
