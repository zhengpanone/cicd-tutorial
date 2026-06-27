# Filebeat DaemonSet 部署

Filebeat 8.13.4，以 DaemonSet 形式运行在每个节点上，收集容器日志并输出到 Elasticsearch。

## 资源清单

| 资源 | 名称 | 说明 |
|------|------|------|
| ConfigMap | filebeat-config | filebeat.yml 主配置 |
| ServiceAccount | filebeat | RBAC 身份 |
| ClusterRole | filebeat | 读取 pods/nodes/namespaces 权限 |
| ClusterRoleBinding | filebeat | 绑定 ServiceAccount 到 ClusterRole |
| DaemonSet | filebeat | 镜像 docker.elastic.co/beats/filebeat:8.13.4 |

所有资源部署在 `elk` 命名空间。

## 部署

```bash
kubectl apply -f filebeat-k8s.yaml
```

## 配置要点

- 输入类型：`type: container`（8.x 版本，替代已废弃的 `type: docker`）
- 日志路径：`/var/log/containers/*.log`
- Kubernetes 元数据：通过 `add_kubernetes_metadata` processor 自动关联
- 输出目标：`elasticsearch.elk.svc.cluster.local:9200`

## 数据持久化

Filebeat registry 数据持久化到 `e:/dockerstore/filebeat/data/`，Pod 重启后不会重复采集已处理的日志。

挂载卷：

| 挂载点 | 来源 | 说明 |
|--------|------|------|
| `/etc/filebeat/filebeat.yml` | ConfigMap | 配置文件 |
| `/usr/share/filebeat/data` | hostPath | registry 持久化 |
| `/var/lib/docker/containers` | hostPath | 容器日志原始文件 |
| `/var/log` | hostPath | 系统日志 |

## 验证

```bash
# 检查 Pod 状态
kubectl get pods -n elk -l app=filebeat

# 查看 Filebeat 日志
kubectl logs -n elk -l app=filebeat --tail=20

# 在 Elasticsearch 中查看 Filebeat 索引
curl -s -H "Host: elasticsearch.k8s" http://localhost:18080/_cat/indices?v | grep filebeat
```
