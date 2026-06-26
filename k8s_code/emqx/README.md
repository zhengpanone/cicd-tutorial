# EMQX Kubernetes 部署

`emqx-k8s.yaml` 是一个适合本地 Docker Desktop / 开发环境的 EMQX 单节点清单，包含：

- `Namespace`: `emqx`
- `PersistentVolume`: `/run/desktop/mnt/host/e/dockerstore/emqx/data`
- `PersistentVolumeClaim`: `emqx-data-pvc`
- `Secret`: Dashboard 默认账号
- `Deployment`: `emqx/emqx:5.3.0`，单副本
- `Service`: NodePort 暴露 MQTT、WebSocket 和 Dashboard
- `Headless Service`: 集群内 DNS 访问

## 启动

```bash
kubectl apply -f emqx-k8s.yaml
kubectl rollout status deployment/emqx -n emqx --timeout=300s
```

## 查看资源

```bash
kubectl get all -n emqx
kubectl get pv emqx-data-pv
kubectl get pvc -n emqx emqx-data-pvc
```

## 访问地址

本机访问：

```text
MQTT TCP: tcp://localhost:31883
MQTT WebSocket: ws://localhost:30083
Dashboard: http://localhost:30084
```

集群内访问：

```text
MQTT TCP: tcp://emqx.emqx.svc.cluster.local:1883
```

Dashboard 默认账号：

```text
admin / public
```

## Spring Boot 测试

`my-springboot-app` 已经配置：

```yaml
EMQX_BROKER_URL=tcp://emqx.emqx.svc.cluster.local:1883
```

如果在本机直接运行 Spring Boot，请改用 NodePort：

```bash
EMQX_BROKER_URL=tcp://localhost:31883 mvn spring-boot:run
```

测试接口见 `k8s_code/my-springboot-app/README.md`。
