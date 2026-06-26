# cert-manager TLS 管理

## 一键部署

```bash
# 1. 安装 cert-manager（首次）
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.yaml

# 等待就绪
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=120s
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=120s
kubectl wait --for=condition=Available deployment/cert-manager-cainjector -n cert-manager --timeout=120s

# 2. 确保命名空间已存在
kubectl create namespace web-app --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace devops --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dinginx-efk --dry-run=client -o yaml | kubectl apply -f -

# 3. 创建证书资源
kubectl apply -f tls-resources.yaml

# 4. 验证各命名空间证书和 Secret
kubectl get certificate -A
kubectl get secret -A | grep -E "tls$|ca-secret"
```

## 架构

```
selfsigned-cluster-issuer (ClusterIssuer, 自签名)
    └── k8s-ca (中间 CA, cert-manager 命名空间, 10年)
            └── k8s-ca-issuer (ClusterIssuer, CA签发器)
                    ├── web-app-tls   (web-app)       → gin/express/springboot.k8s
                    ├── devops-tls    (devops)        → jenkins.k8s
                    ├── default-tls   (default)       → nacos/consul/rustfs/prometheus/jaeger/sentinel/minio/rocketmq/redisinsight/attu.k8s
                    └── efk-tls       (dinginx-efk)   → kibana.k8s
```

## 新增域名

1. 编辑 `tls-resources.yaml`，在对应命名空间 Certificate 的 `dnsNames` 中添加新域名
2. 在 `infra-ingress.yaml` 或 `web-app-ingress.yaml` 中添加 Ingress 资源
3. 在 Windows hosts 文件中添加 `127.0.0.1 <新域名>`

```bash
kubectl apply -f tls-resources.yaml
kubectl apply -f infra-ingress.yaml
```

cert-manager 会自动重新签发证书并更新 Secret。

## 切换到 Let's Encrypt

将 `k8s-ca-issuer` 替换为 Let's Encrypt ClusterIssuer，所有 Certificate 的 issuerRef 改指向它即可，Ingress 零修改。
