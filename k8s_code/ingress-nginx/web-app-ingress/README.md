# Web 应用 Ingress 路由

管理 `web-app` 命名空间下三个示例应用（gin、express、springboot）的 Ingress 路由规则。

## 路由表

| 域名 | Service | 端口 | TLS Secret |
|------|---------|------|------------|
| gin.k8s | my-gin-app | 8080 | web-app-tls |
| express.k8s | my-express-app | 3000 | web-app-tls |
| springboot.k8s | my-springboot-app | 8080 | web-app-tls |

三个 Ingress 共享同一个 TLS Secret `web-app-tls`，由 `cert-manager/tls-resources.yaml` 中的 Certificate 资源自动生成。

## 配置说明

所有 Ingress 均设置了以下注解，允许 HTTP 和 HTTPS 同时访问，不强制跳转：

```yaml
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "false"
  nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
```

## 部署

```bash
kubectl apply -f web-app-ingress.yaml
```

## 访问

```bash
curl http://gin.k8s:28080
curl -k https://gin.k8s:28443
```
