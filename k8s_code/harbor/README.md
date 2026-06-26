# Harbor on Kubernetes

Harbor 是企业级容器镜像仓库，提供镜像签名、漏洞扫描、RBAC 权限控制、镜像复制等功能。本目录提供在 Docker Desktop Kubernetes 单节点环境下的手动部署清单，包含 8 个微服务组件。

## 架构说明

| 组件 | 镜像 | 端口 | 类型 | 说明 |
|---|---|---|---|---|
| harbor-nginx | goharbor/nginx-photon:v2.15.1 | 8080 | Deployment | 反向代理，统一入口 |
| harbor-portal | goharbor/harbor-portal:v2.15.1 | 8080 | Deployment | Web UI 前端（Angular） |
| harbor-core | goharbor/harbor-core:v2.15.1 | 8080 | Deployment | 核心 API，认证/鉴权/项目管理 |
| harbor-registry | goharbor/registry-photon:v2.15.1 | 5000 | Deployment | 镜像和 OCI 制品存储 |
| harbor-registryctl | goharbor/harbor-registryctl:v2.15.1 | 8080 | Deployment | Registry 生命周期管理 |
| harbor-jobservice | goharbor/harbor-jobservice:v2.15.1 | 8080 | Deployment | 异步任务引擎（GC/扫描/复制） |
| harbor-database | goharbor/harbor-db:v2.15.1 | 5432 | StatefulSet | PostgreSQL 元数据库 |
| harbor-redis | goharbor/redis-photon:v2.15.1 | 6379 | Deployment | 缓存和会话存储 |

**组件通信链路：**

```
Docker CLI / 浏览器
    → harbor-nginx (反向代理)
        → /api/* /c/* /service/* → harbor-core
        → /v2/* → harbor-registry
        → /* → harbor-portal
    harbor-core
        → harbor-database (PostgreSQL)
        → harbor-redis (缓存)
        → harbor-registry (镜像存储)
        → harbor-registryctl (Registry 管理)
        → harbor-jobservice (异步任务)
```

## 资源说明

| 资源类型 | 名称 | 说明 |
|---|---|---|
| Namespace | harbor | 独立命名空间 |
| PersistentVolume | harbor-registry-pv | 镜像存储 20Gi，hostPath |
| PersistentVolume | harbor-database-pv | 数据库 5Gi，hostPath |
| PersistentVolume | harbor-redis-pv | Redis 2Gi，hostPath |
| PersistentVolume | harbor-jobservice-pv | 任务日志 2Gi，hostPath |
| PersistentVolumeClaim | harbor-*-pvc | 对应 4 个 PVC |
| ConfigMap | harbor-core-config | Core 应用配置 + 环境变量 |
| ConfigMap | harbor-nginx-config | Nginx 反向代理配置 |
| ConfigMap | harbor-registry-config | Registry 存储配置 |
| Secret | harbor-secret | 数据库密码、管理员密码、内部密钥 |
| StatefulSet | harbor-database | PostgreSQL 有状态服务 |
| Deployment | harbor-redis/core/portal/registry/registryctl/jobservice/nginx | 7 个无状态服务 |
| Service (Headless) | harbor-database-headless | StatefulSet DNS 发现 |
| Service (ClusterIP) | harbor-redis/core/portal/registry/registryctl/jobservice/nginx | 集群内部通信 |
| Service (NodePort) | harbor-nodeport | 外部访问 30043 |

## 前置条件

1. **hostPath 目录**：部署前确保宿主机路径存在（Docker Desktop 会自动创建 DirectoryOrCreate）

```bash
# Windows 侧路径（Docker Desktop 会自动映射）
E:\dockerstore\harbor\
├── registry\
├── database\
├── redis\
└── jobservice\
```

2. **Kubernetes 上下文**

```bash
kubectl config current-context
# 应输出 docker-desktop
```

3. **cert-manager**：已安装并运行，CA 链已签发（参见 `ingress-nginx/cert-manager/tls-resources.yaml`）

4. **hosts 文件**：添加域名解析

```
127.0.0.1 harbor.k8s
```

5. **Ingress Controller**：nginx-ingress 已部署，端口 18080(HTTP) / 18443(HTTPS)

## 部署

```bash
# 1. 签发 harbor 命名空间 TLS 证书（如果尚未签发）
kubectl apply -f ../ingress-nginx/cert-manager/tls-resources.yaml

# 2. 部署 Harbor 所有资源
kubectl apply -f harbor-k8s.yaml

# 3. 添加 Ingress 路由
kubectl apply -f ../infra-ingress.yaml

# 4. 等待所有 Pod 就绪（harbor-core 依赖数据库和 Redis，启动较慢）
kubectl rollout status deployment/harbor-nginx -n harbor --timeout=300s
kubectl rollout status deployment/harbor-core -n harbor --timeout=300s
kubectl rollout status statefulset/harbor-database -n harbor --timeout=300s
kubectl rollout status deployment/harbor-redis -n harbor --timeout=120s
kubectl rollout status deployment/harbor-registry -n harbor --timeout=120s
kubectl rollout status deployment/harbor-jobservice -n harbor --timeout=300s

# 5. 检查所有 Pod 状态
kubectl get pods -n harbor
```

预期输出：

```text
NAME                                 READY   STATUS    RESTARTS   AGE
harbor-core-xxx                      1/1     Running   0          5m
harbor-database-0                    1/1     Running   0          5m
harbor-jobservice-xxx                1/1     Running   0          5m
harbor-nginx-xxx                     1/1     Running   0          5m
harbor-portal-xxx                    1/1     Running   0          5m
harbor-redis-xxx                     1/1     Running   0          5m
harbor-registry-xxx                  1/1     Running   0          5m
harbor-registryctl-xxx               1/1     Running   0          5m
```

## 访问 Harbor

### 浏览器访问

| 方式 | URL |
|---|---|
| HTTP | http://harbor.k8s:18080 |
| HTTPS | https://harbor.k8s:18443 |

默认管理员账号：`admin` / 密码：`Harbor12345`

### 命令行验证

```bash
# HTTP 访问
curl -s http://harbor.k8s:18080/api/v2.0/health

# HTTPS 访问（自签名证书需 -k）
curl -sk https://harbor.k8s:18443/api/v2.0/health
```

预期返回：`{"status":"healthy"}`

## Docker 客户端配置

### 方式一：配置 insecure-registry（推荐学习使用）

编辑 Docker Desktop 的 daemon.json（Settings → Docker Engine）：

```json
{
  "insecure-registries": ["harbor.k8s"]
}
```

点击 Apply & Restart 后生效。

### 方式二：信任自签名 CA 证书

```bash
# 1. 从集群导出 CA 证书
kubectl get secret k8s-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 -d > harbor-ca.crt

# 2. 配置 Docker 信任该 CA
# Windows: 将 harbor-ca.crt 复制到 C:\Users\<用户名>\.docker\certs.d\harbor.k8s\
mkdir -p "$HOME/.docker/certs.d/harbor.k8s"
cp harbor-ca.crt "$HOME/.docker/certs.d/harbor.k8s/ca.crt"

# 重启 Docker Desktop
```

### 推送镜像测试

```bash
# 登录 Harbor
docker login harbor.k8s
# 用户名: admin  密码: Harbor12345

# 标记并推送测试镜像
docker pull nginx:alpine
docker tag nginx:alpine harbor.k8s/library/nginx:alpine
docker push harbor.k8s/library/nginx:alpine
```

> 注意：推送前需在 Harbor Web UI 中创建 `library` 项目（或使用默认的 library 项目）。

## 常用运维命令

```bash
# 查看所有资源
kubectl get all -n harbor

# 查看某个组件日志
kubectl logs -n harbor deployment/harbor-core --tail=50
kubectl logs -n harbor deployment/harbor-registry --tail=50
kubectl logs -n harbor statefulset/harbor-database --tail=50

# 重启某个组件
kubectl rollout restart deployment/harbor-core -n harbor
kubectl rollout restart deployment/harbor-nginx -n harbor

# 查看 Pod 事件（排查启动问题）
kubectl describe pod -n harbor -l app=harbor-core

# 进入数据库
kubectl exec -it harbor-database-0 -n harbor -- psql -U postgres -d registry

# 进入 Redis
kubectl exec -it $(kubectl get pod -n harbor -l app=harbor-redis -o name) -n harbor -- redis-cli -a harbor12345

# 查看 PVC 使用情况
kubectl get pvc -n harbor
```

## 备份和恢复

```bash
# 备份所有数据（在宿主机 Windows 侧执行）
# 数据位于 E:\dockerstore\harbor\ 目录

# 备份数据库
kubectl exec harbor-database-0 -n harbor -- pg_dump -U postgres registry > harbor-db-backup.sql

# 恢复数据库
kubectl exec -i harbor-database-0 -n harbor -- psql -U postgres registry < harbor-db-backup.sql
```

## 常见问题

### harbor-core CrashLoopBackOff

harbor-core 依赖 PostgreSQL 和 Redis，如果数据库尚未就绪会反复重启。

```bash
# 检查数据库是否就绪
kubectl get pods -n harbor -l app=harbor-database
kubectl logs -n harbor statefulset/harbor-database --tail=20

# 检查 Redis 是否就绪
kubectl get pods -n harbor -l app=harbor-redis
```

Pod 内已配置 `wait-for-database` 和 `wait-for-redis` initContainer，正常情况下会自动等待。如果数据库密码不正确，会导致 core 反复启动失败。

### 镜像推送失败 413 Request Entity Too Large

Ingress 的 `proxy-body-size` 必须设为 `"0"`（无限制），否则推送大镜像会报 413。确认 infra-ingress.yaml 中 Harbor 的 Ingress 注解包含：

```yaml
nginx.ingress.kubernetes.io/proxy-body-size: "0"
```

### 推送镜像报 unauthorized

确认 `EXT_ENDPOINT` 与实际访问 URL 一致。如果使用 `https://harbor.k8s` 作为 EXT_ENDPOINT，则 Docker CLI 必须用 `docker login harbor.k8s`（不带端口号）。如果通过 NodePort 访问，EXT_ENDPOINT 需要包含端口号。

### harbor-database 启动失败 - 权限问题

Docker Desktop 的 hostPath 不支持 fsGroup，依赖 busybox initContainer 修复权限。如果数据库仍然无法写入：

```bash
# 检查 initContainer 是否成功
kubectl describe pod harbor-database-0 -n harbor | grep -A 10 Init

# 手动修复权限
kubectl exec harbor-database-0 -n harbor -c fix-permissions -- chown -R 999:999 /var/lib/postgresql/data
```

### 证书不生效 / HTTPS 访问失败

```bash
# 检查 harbor-tls Secret 是否已生成
kubectl get secret harbor-tls -n harbor

# 检查 Certificate 状态
kubectl get certificate harbor-tls -n harbor
kubectl describe certificate harbor-tls -n harbor

# 如果 Secret 不存在，重新 apply tls-resources.yaml
kubectl apply -f ../ingress-nginx/cert-manager/tls-resources.yaml
```

## 清理资源

```bash
# 删除 Harbor 所有资源
kubectl delete -f harbor-k8s.yaml
kubectl delete namespace harbor

# 清理 hostPath 数据（在宿主机 Windows 侧）
# 删除 E:\dockerstore\harbor\ 目录
```

> 注意：删除 namespace 会自动清理该命名空间下的所有资源，包括 PV/PVC 绑定关系。但 hostPath 目录下的宿主机数据不会自动删除，需手动清理。
