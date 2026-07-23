# ingress-nginx 总览

本目录统一管理 Ingress 控制器配置、TLS 证书和所有应用路由规则。

## 目录结构

```
ingress-nginx/
├── README.md                    ← 本文件
├── cert-manager/                ← TLS 证书管理（cert-manager）
│   ├── README.md
│   └── tls-resources.yaml       ← ClusterIssuer + 各命名空间证书
├── ingress-nginx/               ← Ingress Controller 配置
│   ├── README.md
│   └── nginx-port-patch.yaml    ← Service 端口补丁（28080/28443）
└── web-app-ingress/             ← Web 应用路由
    ├── README.md
    └── web-app-ingress.yaml     ← gin / express / springboot Ingress
```

基础设施服务（jenkins、nacos、consul 等）的 Ingress 在 `k8s_code/infra-ingress.yaml`。

## 快速部署

```bash
# 1. 修改 Ingress Controller 端口（仅首次或端口变更后）
kubectl apply -f ingress-nginx/nginx-port-patch.yaml
kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/ports","value":[{"containerPort":80,"name":"http","protocol":"TCP"},{"containerPort":443,"name":"https","protocol":"TCP"},{"containerPort":8443,"name":"webhook","protocol":"TCP"}]}]'

# 2. 创建 TLS 证书（依赖 cert-manager 已安装）
kubectl apply -f cert-manager/tls-resources.yaml

# 3. 部署路由规则
kubectl apply -f web-app-ingress/web-app-ingress.yaml
kubectl apply -f ../infra-ingress.yaml
```

## 访问方式

所有服务通过 `<服务名>.k8s` 域名访问，需在 Windows hosts 文件中添加 `127.0.0.1` 映射。

| 端口 | 协议 | 示例 |
|------|------|------|
| 28080 | HTTP | `http://gin.k8s:28080` |
| 28443 | HTTPS | `https://gin.k8s:28443` |

## 新增服务

1. 在 `infra-ingress.yaml` 或 `web-app-ingress/web-app-ingress.yaml` 中添加 Ingress 资源
2. 在 `cert-manager/tls-resources.yaml` 对应命名空间的 Certificate `dnsNames` 中添加域名
3. 在 Windows hosts 文件中添加 `127.0.0.1 <域名>`
