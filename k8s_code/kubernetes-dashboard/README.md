# Kubernetes Dashboard 管理员账号

Dashboard 管理界面的集群管理员登录凭证。Dashboard 本身通过官方 manifest 部署在 `kubernetes-dashboard` 命名空间。

## 资源清单

| 资源 | 名称 | 说明 |
|------|------|------|
| ServiceAccount | dashboard-admin | 管理员身份 |
| ClusterRoleBinding | dashboard-admin | 绑定 cluster-admin 角色 |
| Secret | dashboard-admin-token | 持久 Token（备用） |
| Service (NodePort) | kubernetes-dashboard-nodeport | 外部访问，端口 30443 |

## 部署

```bash
# 部署 Dashboard（如尚未安装）
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# 创建管理员账号
kubectl apply -f dashboard-admin.yaml
```

## 获取登录 Token

```bash
# 方式一：生成长期 Token（1 年有效，推荐）
kubectl create token dashboard-admin -n kubernetes-dashboard --duration=8760h

# 方式二：获取持久 Token（不过期，备用）
kubectl get secret dashboard-admin-token -n kubernetes-dashboard -o jsonpath="{.data.token}" | base64 -d
```

> **注意：** 如方式二登录失败，请使用方式一（Dashboard v2.7.0 + K8s 1.24+ 可能拒绝静态 Token）。

## 访问

Ingress 域名：

```bash
http://dashboard.k8s:18080
https://dashboard.k8s:18443
```

NodePort 直接访问：

```bash
https://localhost:30443
```

需先在 hosts 文件添加 `127.0.0.1 dashboard.k8s`。打开后选择 **Token** 登录方式，粘贴上一步获取的 Token。

> **注意：** Ingress 需要 `backend-protocol: HTTPS` 注解，因为 Dashboard 后端默认使用 HTTPS。
