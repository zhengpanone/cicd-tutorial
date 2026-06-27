# Headlamp on Kubernetes

Headlamp 是 K8s 官方推荐的 Kubernetes Dashboard 替代品，由 [kubernetes-sigs](https://github.com/kubernetes-sigs/headlamp) 维护。界面更现代，功能更丰富，Token 认证兼容 K8s 1.24+。本目录提供在 Docker Desktop Kubernetes 上的部署清单，替代已归档的 kubernetes-dashboard 项目。

## 资源说明

| 资源类型 | 名称 | 说明 |
|---|---|---|
| ServiceAccount | headlamp-admin | 管理员身份，包含官方示例的 `kube-system` 和当前部署用的 `kubernetes-dashboard` |
| ClusterRoleBinding | headlamp-admin | 绑定 `cluster-admin` 角色 |
| Deployment | headlamp | Headlamp latest（in-cluster 模式，默认集群名 `main`） |
| Service (ClusterIP) | headlamp | 集群内部通信，端口 80 → 4466 |
| Service (NodePort) | headlamp-nodeport | 外部访问，端口 30443 |
| Ingress | headlamp | 通过 `headlamp.k8s` 访问 |

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
# 官方文档推荐方式（Kubernetes 1.24+）
kubectl create token headlamp-admin -n kube-system
```

复制输出的完整 Token，在 Headlamp 登录页面粘贴即可。Token 很长，建议从终端中一次性复制整行内容，不要额外带入空格或手动换行。

如需生成长期 Token，可追加有效期：

```bash
kubectl create token headlamp-admin -n kube-system --duration=8760h
```

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

Headlamp 官方文档推荐用 ServiceAccount Token 登录。本清单创建了官方示例中的 `kube-system/headlamp-admin` 并绑定 `cluster-admin`，请优先使用下面的 Token：

```bash
kubectl create token headlamp-admin -n kube-system
```

本清单已经加入 `-me-username-path=sub`，Headlamp 可以从 Kubernetes ServiceAccount Token 的 `sub` 字段识别用户名。

先确认服务端认证链路是否正常：

```bash
TOKEN=$(kubectl create token headlamp-admin -n kube-system)

curl -i -c /tmp/headlamp-cookie.txt \
  -H 'Content-Type: application/json' \
  -d "{\"token\":\"${TOKEN}\"}" \
  http://localhost:30443/clusters/main/set-token

curl -b /tmp/headlamp-cookie.txt \
  http://localhost:30443/clusters/main/me
```

如果 `/me` 返回的 `username` 是 `system:serviceaccount:kube-system:headlamp-admin`，说明 Headlamp、Token 和 RBAC 都是正常的。如果页面仍然失败，在浏览器中清理当前访问地址的站点数据后重新登录：

1. 退出 Headlamp 或直接关闭页面。
2. 清理 `localhost:30443`、`127.0.0.1:30443`、`headlamp.k8s:18080`、`headlamp.k8s:18443` 中实际使用地址的 Cookie / Site data。
3. 重新打开 Headlamp，粘贴新生成的完整 Token。

如果需要绕开浏览器已有站点数据，也可以换一个未登录过的访问地址快速验证，例如从 `http://localhost:30443` 换到 `http://127.0.0.1:30443` 或 `http://127.0.0.2:30443`。


### Token 获取失败

确认 ServiceAccount 和 ClusterRoleBinding 已正确创建：

```bash
kubectl get sa headlamp-admin -n kubernetes-dashboard
kubectl get sa headlamp-admin -n kube-system
kubectl get clusterrolebinding headlamp-admin
```

## 清理资源

```bash
kubectl delete -f headlamp-k8s.yaml
```
