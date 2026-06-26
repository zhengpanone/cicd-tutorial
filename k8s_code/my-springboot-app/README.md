# my-springboot-app

Spring Boot 示例应用，提供基础 HTTP 接口和 EMQX MQTT 测试接口。

## EMQX 配置

默认配置在 `src/main/resources/application.yml`：

```yaml
emqx:
  broker-url: ${EMQX_BROKER_URL:tcp://localhost:1883}
  client-id-prefix: ${EMQX_CLIENT_ID_PREFIX:my-springboot-app}
```

在 Kubernetes 中，`my-springboot-k8s.yaml` 已配置为访问集群内 EMQX：

```yaml
EMQX_BROKER_URL=tcp://emqx.emqx.svc.cluster.local:1883
```

本机调试时，如果 EMQX 通过 `k8s_code/emqx/emqx-k8s.yaml` 启动，请使用 NodePort：

```bash
$env:EMQX_BROKER_URL="tcp://localhost:31883"
mvn spring-boot:run
```

## EMQX 测试接口

查看当前 MQTT 配置：

```bash
curl http://localhost:8080/emqx/config
```

发布一条 MQTT 消息：

```bash
curl -X POST "http://localhost:8080/emqx/publish?topic=cicd-tutorial/emqx/test&payload=hello-emqx&qos=1"
```

订阅并发布同一条消息，验证 EMQX 往返链路：

```bash
curl -X POST "http://localhost:8080/emqx/roundtrip?topic=cicd-tutorial/emqx/test&payload=hello-emqx&qos=1&timeoutSeconds=5"
```

返回 `success: true` 表示 Spring Boot 已经成功连接 EMQX，并完成发布/订阅验证。

## 构建镜像

```bash
docker build -t my-springboot-app:1.0.0 .
```

## 本地运行镜像

```bash
docker run -d \
  -p 18080:8080 \
  -e EMQX_BROKER_URL=tcp://host.docker.internal:31883 \
  --name my-springboot-app \
  my-springboot-app:1.0.0
```

## 推送到本地镜像仓库

```bash
docker tag my-springboot-app:1.0.0 host.docker.internal:5001/my-springboot-app:1.0.0
docker push host.docker.internal:5001/my-springboot-app:1.0.0
```

## 部署应用

先启动 EMQX：

```bash
kubectl apply -f ../emqx/emqx-k8s.yaml
kubectl rollout status deployment/emqx -n emqx --timeout=300s
```

部署 Spring Boot：

```bash
kubectl apply -f my-springboot-k8s.yaml
kubectl rollout status deployment/my-springboot-app -n web-app --timeout=300s
```

验证应用资源：

```bash
kubectl get pods -n web-app
kubectl get svc -n web-app
kubectl get endpoints -n web-app
```

通过 NodePort 访问 Spring Boot：

```text
http://localhost:30004
```

如果需要从本机访问 EMQX Dashboard：

```text
http://localhost:30084
```

## 清理本地镜像

```bash
docker rmi my-springboot-app:1.0.0
docker rmi host.docker.internal:5001/my-springboot-app:1.0.0
```
