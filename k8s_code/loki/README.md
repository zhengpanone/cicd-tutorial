# Loki on Kubernetes

Loki 是 Grafana 开发的水平可扩展、高可用、多租户日志聚合系统。它的设计理念深受 Prometheus 启发，只索引日志的标签（labels），不对日志全文建索引，因此存储成本低、运维简单。本目录提供在 Docker Desktop Kubernetes 上的单实例部署清单。

## 资源说明

| 资源类型 | 名称 | 说明 |
|---|---|---|
| PersistentVolume | loki-data-pv | 数据持久化 10Gi，hostPath |
| PersistentVolumeClaim | loki-data-pvc | 绑定 PV |
| ConfigMap | loki-config | Loki 运行配置（local-config.yaml） |
| Deployment | loki | Loki 3.4.2 单实例 |
| Service (ClusterIP) | loki | 集群内部通信，HTTP 3100 / gRPC 9096 |
| Service (NodePort) | loki-nodeport | 外部访问，HTTP 31920 / gRPC 31921 |

## 前置条件

1. **hostPath 目录**：`E:\dockerstore\loki\`（自动创建）
2. **Kubernetes 上下文**：确认当前上下文为 docker-desktop

```bash
kubectl config current-context
```

## 部署

```bash
# 部署 Loki
kubectl apply -f loki-k8s.yaml

# 等待 Pod 就绪（Loki 启动较慢，需等待索引初始化）
kubectl rollout status deployment/loki -n default --timeout=180s

# 检查状态
kubectl get pods -n default -l app=loki
```

预期输出：

```text
NAME                     READY   STATUS    RESTARTS   AGE
loki-xxx                 1/1     Running   0          90s
```

## 验证 Loki 就绪

```bash
# 健康检查
curl -s http://localhost:31920/ready

# 查询日志（需先有数据写入）
curl -s 'http://localhost:31920/loki/api/v1/query' --data-urlencode 'query={app=~".+"}' | head -20
```

## 访问 Loki

| 方式 | 地址 |
|---|---|
| 集群内部 | http://loki.default.svc.cluster.local:3100 |
| Ingress HTTP | http://loki.k8s:18080 |
| Ingress HTTPS | https://loki.k8s:18443 |
| NodePort (HTTP) | http://localhost:31920 |
| NodePort (gRPC) | localhost:31921 |

## 与 Grafana 集成

Loki 部署完成后，在 Grafana 中添加数据源：

1. 打开 Grafana → **Connections → Data sources → Add data source**
2. 选择 **Loki**
3. URL 填写 `http://loki.default.svc.cluster.local:3100`
4. 点击 **Save & Test**

如果 Grafana 已部署本项目的 `grafana-k8s.yaml`，Loki 数据源已通过 provisioning 自动配置（URL 为 `http://loki:3100`，同命名空间短名可达）。

## 与 Filebeat 集成

Filebeat 可将 Kubernetes 日志推送到 Loki。在 Filebeat 配置中指定 Loki 地址：

```yaml
output.logstash:
  hosts: ["loki.default.svc.cluster.local:3100"]
```

或使用 Promtail 作为日志收集 agent（Loki 原生推荐）。

## 常用运维命令

```bash
# 查看日志
kubectl logs -n default deployment/loki --tail=50

# 重启 Loki
kubectl rollout restart deployment/loki -n default

# 进入容器
kubectl exec -it $(kubectl get pod -n default -l app=loki -o name) -n default -- sh

# 查看存储用量
kubectl exec $(kubectl get pod -n default -l app=loki -o name) -n default -- du -sh /loki
```

## 常见问题

### Pod 启动失败 - 权限问题

Loki 以 UID 10001 运行，Docker Desktop hostPath 需要 initContainer 修复权限：

```bash
kubectl describe pod -n default -l app=loki | grep -A 5 Init
```

### Pod 启动慢

Loki 首次启动需要初始化索引和存储目录，可能需要 60-90 秒。readiness probe 设置了较长的 `initialDelaySeconds: 30` 和 `failureThreshold: 5`。

### 查询返回空结果

确认有日志数据写入 Loki。可通过 Promtail 或 Filebeat 推送日志，或使用 curl 测试：

```bash
# 查询最近 1 小时的日志
curl -s 'http://localhost:31920/loki/api/v1/query_range' \
  --data-urlencode 'query={app=~".+"}' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s)000000000 \
  --data-urlencode 'end='$(date +%s)000000000
```

### 磁盘空间不足

Loki 默认保留所有日志，可通过 `compactor.retention_enabled` 和 `compactor.retention_period` 配置保留策略。当前配置默认保留 7 天（168h）。

## 清理资源

```bash
kubectl delete -f loki-k8s.yaml
# 清理宿主机数据：删除 E:\dockerstore\loki\
```
