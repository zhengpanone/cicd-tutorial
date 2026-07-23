# Ingress Controller 端口配置

解决 Docker Desktop 环境下宿主机 80/443 端口被占用的问题。

## 背景

Docker Desktop Kubernetes 通过 LoadBalancer Service 将端口转发到 Windows 宿主机。当 80 端口已被其他服务占用时，需要将 Ingress Controller 的对外端口改为 28080（HTTP）和 28443（HTTPS）。

## 修改内容

`nginx-port-patch.yaml` 将 ingress-nginx-controller Service 的端口从默认的 80/443 改为 28080/28443：

```yaml
ports:
  - port: 28080    # HTTP（原 80）
    targetPort: http
  - port: 28443    # HTTPS（原 443）
    targetPort: https
```

## 使用

```bash
# 1. 更新 Service 端口
kubectl apply -f nginx-port-patch.yaml

# 2. 去掉 Deployment 的 hostPort（由 Service 统一转发）
kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/ports","value":[{"containerPort":80,"name":"http","protocol":"TCP"},{"containerPort":443,"name":"https","protocol":"TCP"},{"containerPort":8443,"name":"webhook","protocol":"TCP"}]}]'
```

> **注意：** Docker Desktop 不一定转发所有 hostPort，使用 Service port 方式更可靠。
