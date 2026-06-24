# my-springboot-app

## 构建镜像

```bash
docker build -t my-springboot-app:1.0.0 .
```

## 本地运行镜像

```bash
docker run -d \
  -p 18080:8080 \
  --name my-springboot-app \
  my-springboot-app:1.0.0
```

## 推送到本地镜像仓库

```bash
docker tag my-springboot-app:1.0.0 host.docker.internal:5001/my-springboot-app:1.0.0
docker push host.docker.internal:5001/my-springboot-app:1.0.0
```

## 清理本地镜像

```bash
docker rmi my-springboot-app:1.0.0
docker rmi host.docker.internal:5001/my-springboot-app:1.0.0
```

## 安装 Gateway API

`my-springboot-k8s.yaml` 使用了：

```text
gateway.networking.k8s.io/v1
```

首次部署前需要先安装 Gateway API CRD，否则会出现：

```text
no matches for kind "Gateway" in version "gateway.networking.k8s.io/v1"
no matches for kind "HTTPRoute" in version "gateway.networking.k8s.io/v1"
```

安装 Gateway API 标准 CRD：

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
```

验证 CRD：

```bash
kubectl get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io
```

## 安装 Gateway Controller

只安装 Gateway API CRD 只能让 Kubernetes 识别 `Gateway` 和 `HTTPRoute` 资源，还需要安装 Gateway Controller 才能真正处理流量。

本清单使用：

```yaml
gatewayClassName: nginx
```

因此可以安装 NGINX Gateway Fabric：

```bash
kubectl apply --server-side -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.6.5/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.6.5/deploy/nodeport/deploy.yaml
```

验证 Gateway Controller：

```bash
kubectl get gatewayclass
kubectl get pods -n nginx-gateway
kubectl get svc -n nginx-gateway
```

应能看到 `GatewayClass/nginx`。

## 部署应用

```bash
kubectl apply -f my-springboot-k8s.yaml
```

验证应用资源：

```bash
kubectl get pods -n spring-app
kubectl get svc -n spring-app
kubectl get endpoints -n spring-app
kubectl get gateway -n spring-app
kubectl get httproute -n spring-app
```

查看 Gateway 和 HTTPRoute 状态：

```bash
kubectl describe gateway -n spring-app gateway-demo
kubectl describe httproute -n spring-app spring-restful-service-route
```

重点确认 `Accepted` 和 `Programmed` 状态为 `True`。

## 排查命令

如果 Gateway 或 HTTPRoute 没有生效，先看 Gateway API 资源和 Controller：

```bash
kubectl get gatewayclass
kubectl get gateway -n spring-app
kubectl get httproute -n spring-app
kubectl get pods -n nginx-gateway
kubectl logs -n nginx-gateway -l app.kubernetes.io/name=nginx-gateway-fabric --tail=100
```
