# cert-manager TLS 证书管理

通过 cert-manager 实现集群级自动证书签发和续签，采用自签名 CA 链。

## 前提

cert-manager 已安装：

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.yaml

# 等待就绪
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=120s
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=120s
kubectl wait --for=condition=Available deployment/cert-manager-cainjector -n cert-manager --timeout=120s
```

## 部署

```bash
# 确保目标命名空间已存在
kubectl create namespace web-app --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace devops --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace elk --dry-run=client -o yaml | kubectl apply -f -

# 创建证书资源
kubectl apply -f tls-resources.yaml

# 验证
kubectl get certificate -A
kubectl get secret -A | grep -E "tls$|ca-secret"
```

## 证书架构

```
selfsigned-cluster-issuer (ClusterIssuer, 自签名根)
    └── k8s-ca (中间 CA, cert-manager 命名空间, 10 年)
            └── k8s-ca-issuer (ClusterIssuer, CA 签发器)
                    ├── web-app-tls  (web-app)      → gin/express/springboot.k8s
                    ├── devops-tls   (devops)       → jenkins.k8s
                    ├── default-tls  (default)      → nacos/consul/rustfs/prometheus/jaeger/sentinel/minio/rocketmq/redisinsight/emqx/attu/kafka-ui.k8s
                    ├── efk-tls      (elk)           → kibana/elasticsearch.k8s
                    └── dashboard-tls (kubernetes-dashboard) → dashboard.k8s
```

所有 Issuer 均为 ClusterIssuer（集群级），Certificate 和 Secret 在各目标命名空间内。

## 新增域名

1. 编辑 `tls-resources.yaml`，在对应命名空间 Certificate 的 `dnsNames` 中添加新域名
2. 重新 apply：

```bash
kubectl apply -f tls-resources.yaml
```

cert-manager 会自动重新签发证书并更新 Secret。

## 切换到 Let's Encrypt

将 `k8s-ca-issuer` 替换为 Let's Encrypt ClusterIssuer，所有 Certificate 的 `issuerRef` 改指向它即可，Ingress 配置无需修改。
