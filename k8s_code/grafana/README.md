# Grafana on Kubernetes

Grafana 是开源的可观测性可视化平台，支持 Prometheus、Loki、Elasticsearch 等多种数据源。本目录提供在 Docker Desktop Kubernetes 上的部署清单，已自动配置 Prometheus 和 Loki 数据源。

## 资源说明

| 资源类型 | 名称 | 说明 |
|---|---|---|
| PersistentVolume | grafana-data-pv | 数据持久化 5Gi，hostPath |
| PersistentVolumeClaim | grafana-data-pvc | 绑定 PV |
| ConfigMap | grafana-config | 数据源自动配置 + grafana.ini |
| Deployment | grafana | Grafana 11.4.0 |
| Service (ClusterIP) | grafana | 集群内部通信，端口 3000 |
| Service (NodePort) | grafana-nodeport | 外部访问，端口 30310 |

## 前置条件

1. **hostPath 目录**：`E:\dockerstore\grafana\data\`（自动创建）
2. **Prometheus 已部署**：`kubectl apply -f ../prometheus/prometheus-k8s.yaml`
3. **Loki 已部署**（可选）：`kubectl apply -f ../loki/loki-k8s.yaml`

## 部署

```bash
# 部署 Grafana
kubectl apply -f grafana-k8s.yaml

# 等待 Pod 就绪
kubectl rollout status deployment/grafana -n default --timeout=120s

# 检查状态
kubectl get pods -n default -l app=grafana
```

预期输出：

```text
NAME                       READY   STATUS    RESTARTS   AGE
grafana-xxx                1/1     Running   0          60s
```

## 访问 Grafana

| 方式 | URL |
|---|---|
| Ingress HTTP | http://grafana.k8s:18080 |
| Ingress HTTPS | https://grafana.k8s:18443 |
| NodePort | http://localhost:30310 |

默认账号：`admin` / 密码：`admin`（首次登录后可修改）

## 已配置数据源

部署时通过 ConfigMap 自动配置以下数据源（provisioning）：

| 数据源 | 类型 | URL | 默认 |
|---|---|---|---|
| Prometheus | prometheus | http://prometheus:9090 | 是 |
| Loki | loki | http://loki:3100 | 否 |

可在 Grafana UI 的 **Connections → Data sources** 页面查看和管理。

## 常用运维命令

```bash
# 查看日志
kubectl logs -n default deployment/grafana --tail=50

# 重启 Grafana
kubectl rollout restart deployment/grafana -n default

# 进入容器
kubectl exec -it $(kubectl get pod -n default -l app=grafana -o name) -n default -- sh

# 查看已安装插件
kubectl exec $(kubectl get pod -n default -l app=grafana -o name) -n default -- grafana cli plugins ls
```

## 安装额外插件

通过环境变量 `GF_INSTALL_PLUGINS` 安装插件，修改 grafana-k8s.yaml 中对应值后重新 apply：

```yaml
- name: GF_INSTALL_PLUGINS
  value: grafana-clock-panel,grafana-simple-json-datasource,grafana-piechart-panel
```

## 备份和恢复

```bash
# 备份数据（在宿主机 Windows 侧）
# 数据位于 E:\dockerstore\grafana\data\

# 导出仪表盘（通过 API）
curl -s http://admin:admin@grafana.k8s:18080/api/dashboards/home > dashboard-backup.json
```

## 常见问题

### Pod 无法启动 - 权限问题

Grafana 以 UID 472 运行，Docker Desktop hostPath 需要 initContainer 修复权限：

```bash
kubectl describe pod -n default -l app=grafana | grep -A 5 Init
```

### Prometheus 数据源连接失败

确认 Prometheus 服务在同一命名空间（default）且 Service 名为 `prometheus`：

```bash
kubectl get svc -n default -l app=prometheus
```

### Ingress 404

确认 hosts 文件包含 `127.0.0.1 grafana.k8s`，且 Ingress 已 apply。

## 清理资源

```bash
kubectl delete -f grafana-k8s.yaml
# 清理宿主机数据：删除 E:\dockerstore\grafana\data\
```
