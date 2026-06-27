# Kafka KRaft 集群 + Kafka UI Dashboard

3 节点 Kafka KRaft 集群（无 ZooKeeper）+ provectuslabs/kafka-ui 可视化管理。

## 资源清单

| 资源 | 名称 | 说明 |
|------|------|------|
| ConfigMap | kafka-kraft-config | KRaft 配置 + cluster.id |
| Service (Headless) | kafka-headless | StatefulSet 集群发现 |
| Service (ClusterIP) | kafka-bootstrap | 集群内部连接入口 |
| Service (NodePort) | kafka-external | 外部访问，端口 30094 |
| StatefulSet | kafka | 3 副本，镜像 confluentinc/cp-kafka:7.4.0 |
| Deployment | kafka-ui | Kafka UI Dashboard |
| Service | kafka-ui | Kafka UI ClusterIP |
| Ingress | kafka-ui | 域名 kafka-ui.k8s |

## 部署

```bash
kubectl apply -f kafka-k8s.yaml
```

## 监听器

| 名称 | 端口 | 用途 |
|------|------|------|
| PLAINTEXT | 9092 | 集群内部通信 |
| CONTROLLER | 9093 | KRaft 控制器通信 |
| EXTERNAL | 9094 | 外部客户端连接（NodePort 30094） |

EXTERNAL 的 `advertised.listeners` 通过 downward API（`status.hostIP`）动态获取宿主机 IP，无需硬编码。

## 数据持久化

数据存储在 `e:/dockerstore/kafka/broker-{0,1,2}/`，包含：

- `logs/` — 消息日志
- `meta/` — KRaft 元数据

> **注意：** Docker Desktop hostPath 不支持 fsGroup，initContainer 使用 busybox 以 root 身份 `chown -R 1000:1000` 修复目录权限。

## ConfigMap 占位符

Kafka 配置中使用纯文本占位符，由容器启动时 sed 替换：

| 占位符 | 替换为 | 说明 |
|--------|--------|------|
| `__POD_NAME__` | `${HOSTNAME}` | Pod 名称（kafka-0/1/2） |
| `__NODE_IP__` | `${NODE_IP}` | 宿主机 IP（downward API） |
| `${BROKER_ID}` | `${HOSTNAME##*-}` | 节点 ID（0/1/2） |

> **注意：** confluentinc/cp-kafka 镜像中的 sed 会将 `$(VAR)` 当作正则捕获组报 `Invalid back reference`，因此使用 `__VAR__` 纯文本标记避免冲突。

## Kafka UI Dashboard

访问地址：

```bash
http://kafka-ui.k8s:18080
https://kafka-ui.k8s:18443
```

需先在 hosts 文件添加 `127.0.0.1 kafka-ui.k8s`。

Kafka UI 通过内部 `kafka-bootstrap:9092` 连接集群，支持 Topic 管理、消息浏览、Consumer Group 监控等功能。

## 验证

```bash
# 检查 Pod 状态
kubectl get pods -n default -l app=kafka

# 在容器内列出 Topics
kubectl exec kafka-0 -n default -- bash -c "kafka-topics --bootstrap-server localhost:9092 --list"

# 创建测试 Topic
kubectl exec kafka-0 -n default -- bash -c "kafka-topics --bootstrap-server localhost:9092 --create --topic test --partitions 3 --replication-factor 3"
```
