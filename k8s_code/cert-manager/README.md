# cert-manager TLS 管理

## 一键部署

```bash
# 1. 安装 cert-manager（首次）
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.yaml

# 等待就绪
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=120s
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=120s
kubectl wait --for=condition=Available deployment/cert-manager-cainjector -n cert-manager --timeout=120s

# 2. 确保 web-app 命名空间已存在
kubectl create namespace web-app --dry-run=client -o yaml | kubectl apply -f -

# 3. 创建证书资源
kubectl apply -f tls-resources.yaml

# 4. 验证证书和 Secret 已自动生成
kubectl get certificate -n web-app
kubectl get secret web-app-tls -n web-app
```

## 工作原理

```
selfsigned-issuer (自签名)
    └── web-app-ca (中间 CA, 10年)
            └── web-app-ca-issuer (CA签发器)
                    └── web-app-tls (应用证书, 1年, 到期前30天自动续签)
                            └── Secret: web-app-tls
                                    ├── gin.k8s
                                    ├── express.k8s
                                    └── springboot.k8s
```

## 新增域名

编辑 `tls-resources.yaml`，在 Certificate 的 `dnsNames` 中添加新域名，然后：

```bash
kubectl apply -f tls-resources.yaml
```

cert-manager 会自动重新签发证书并更新 Secret。

## 切换到真实证书（Let's Encrypt）

将 ClusterIssuer 换成 Let's Encrypt，Certificate 的 issuerRef 改指向它即可，应用 YAML 零修改。
