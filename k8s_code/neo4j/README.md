# Neo4j Kubernetes 部署

`neo4j-k8s.yaml` 是一个适合 Docker Desktop / 本地 Kubernetes 的 Neo4j 单节点部署清单，参考了 `docker-compose/docker-compose.yml` 中的 Neo4j 配置。

## 资源清单

| 资源类型 | 名称 | 说明 |
|---|---|---|
| PersistentVolume | neo4j-data-pv | Neo4j 数据目录，10Gi |
| PersistentVolume | neo4j-import-pv | Neo4j 导入目录，2Gi |
| PersistentVolume | neo4j-plugins-pv | Neo4j 插件目录，2Gi |
| PersistentVolumeClaim | neo4j-data-pvc | 绑定数据 PV |
| PersistentVolumeClaim | neo4j-import-pvc | 绑定导入 PV |
| PersistentVolumeClaim | neo4j-plugins-pvc | 绑定插件 PV |
| Secret | neo4j-secret | Neo4j 默认账号密码 |
| ConfigMap | neo4j-config | 监听地址、内存和 APOC 配置 |
| Service | neo4j-headless | StatefulSet 稳定网络标识 |
| StatefulSet | neo4j | Neo4j 单节点实例 |
| Service | neo4j | 集群内部访问 |
| Service | neo4j-nodeport | 本机 NodePort 访问 |

## 配置说明

默认镜像：

```text
neo4j:2025.02.0-ubi9
```

默认账号：

```text
neo4j / neo4j1234
```

hostPath 持久化目录：

```text
E:\dockerstore\neo4j\data
E:\dockerstore\neo4j\import
E:\dockerstore\neo4j\plugins
```

Kubernetes 中对应路径：

```text
/run/desktop/mnt/host/e/dockerstore/neo4j/data
/run/desktop/mnt/host/e/dockerstore/neo4j/import
/run/desktop/mnt/host/e/dockerstore/neo4j/plugins
```

## 部署

```bash
kubectl apply -f neo4j-k8s.yaml
kubectl rollout status statefulset/neo4j -n default --timeout=300s
```

查看资源状态：

```bash
kubectl get pods -l app=neo4j
kubectl get svc neo4j neo4j-nodeport
kubectl get pv,pvc | grep neo4j
```

## 访问地址

本机访问：

```text
Neo4j Browser: http://localhost:30747
Bolt: bolt://localhost:30687
```

集群内访问：

```text
Neo4j Browser: http://neo4j.default.svc.cluster.local:7474
Bolt: bolt://neo4j.default.svc.cluster.local:7687
```

## 验证

通过 Neo4j Browser 登录后执行：

```cypher
RETURN 1 AS ok;
```

通过容器内 `cypher-shell` 验证：

```bash
kubectl exec -it statefulset/neo4j -- cypher-shell -u neo4j -p neo4j1234 "RETURN 1 AS ok;"
```

查看日志：

```bash
kubectl logs -n default statefulset/neo4j --tail=100
```

## 常用运维命令

```bash
# 重启 Neo4j
kubectl rollout restart statefulset/neo4j -n default

# 进入容器
kubectl exec -it statefulset/neo4j -- bash

# 查看数据目录
kubectl exec -it statefulset/neo4j -- ls -lah /data

# 查看插件目录
kubectl exec -it statefulset/neo4j -- ls -lah /plugins
```

## 常见问题

### Pod 启动较慢

Neo4j 首次启动会初始化系统库和数据目录，`startupProbe` 预留了较长时间。可通过日志观察启动进度：

```bash
kubectl logs -n default statefulset/neo4j -f
```

### 数据目录权限问题

清单中包含 `fix-permissions` initContainer，会将 `/data`、`/import`、`/plugins`、`/logs` 权限调整给 Neo4j 用户。如果 Pod 卡在初始化阶段，可查看事件：

```bash
kubectl describe pod -n default -l app=neo4j
```

### 修改默认密码

首次部署前修改 `neo4j-secret` 中的 `NEO4J_AUTH`：

```yaml
stringData:
  NEO4J_AUTH: neo4j/your-password
```

Neo4j 初始化后，密码会写入数据目录。已有数据目录情况下仅修改 Secret 不一定会重置旧密码。

## 清理

```bash
kubectl delete -f neo4j-k8s.yaml
```

如需彻底清理本地数据，请手动删除：

```text
E:\dockerstore\neo4j\
```
