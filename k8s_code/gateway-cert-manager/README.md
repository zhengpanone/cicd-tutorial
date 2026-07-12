# gateway-cert-manager(Let's Encrypt staging 链路)

⚠️ **本目录依赖 Gateway API,先看 `gateway/README.md` 的"前置依赖"小节**。

## ⚠️ 强警告:域名必须替换

现有 yaml 里所有 `dnsNames` / `hostnames` 都用了占位 `k8s`(例如 `my-gin-app.k8s`)。

**Let's Encrypt staging 不能给以下域名签发证书**:
- `*.k8s`、`*.local`、`*.example.com`
- 任何无法被 LE 通过 HTTP-01 challenge 校验 DNS 解析的域名

如果直接 apply,**所有 Certificate 会永久 Pending**,HTTPRoute 仍然能工作但会拿到 default self-signed cert(很丑)。

## 必须做的事

```bash
# 1. 拥有/管理一个真实可解析域名(例如 dev.example.com)
# 2. 把 *.dev.example.com 通配 CNAME 到 istio-ingressgateway 的 LoadBalancer IP
#    例如 dig istio-ingressgateway.istio-system.svc 得到 ClusterIP,
#    或者 kubectl get svc -n istio-system istio-ingressgateway 看 EXTERNAL-IP
export DOMAIN_SUFFIX=dev.example.com

# 3. 替换占位
find gateway-cert-manager -name '*.yaml' \
  -exec sed -i "s/k8s/${DOMAIN_SUFFIX}/g" {} +

# 4. 替换 cluster-issuer.yaml 的 email 字段
#    当前默认占位 admin@k8s.local(LE 会 reject),仅作 deploy 前必须修改的标记
sed -i 's/admin@k8s.local/your-real-email@example.com/i' \
  gateway-cert-manager/cluster-issuer.yaml

# 5. apply
kubectl apply -f gateway-cert-manager/cluster-issuer.yaml
kubectl apply -f gateway-cert-manager/certificates.yaml

# 6. 等证书
kubectl get certificate -A
# READY=True 即签发成功;Pending 则说明 HTTP-01 challenge 失败,常见原因:
#   - DNS 没解析到 istio-ingressgateway EXTERNAL-IP
#   - 80 端口被防火墙挡
#   - cert-manager 版本 < 1.14 且未启用 gateway solver
```

## 本地 minikube / kind 场景

Ingress Gateway 没有公网 IP,LE HTTP-01 challenge 永远失败。两个解法:

### 方案 A:用 mkcert 临时签发(推荐用于本地)

```bash
# 一次性生成 mkcert CA + 临时 cert
mkcert -cert-file tls.crt -key-file tls.key \
  "*.dev.example.com"

# 手动塞进各 namespace 的 Secret
kubectl create secret tls web-app-tls \
  --cert=tls.crt --key=tls.key -n web-app --dry-run=client -o yaml | kubectl apply -f -
# ... 重复 7 次,各 ns 的 Secret 名见 certificates.yaml
```

### 方案 B:接受 staging 失败,只看 cert-manager 工作流

保留本目录文件不动,Certificate 会一直 Pending,但可以通过 `kubectl describe certificate` / `kubectl logs -n cert-manager` 让学员看到 cert-manager 完整流程(订单生成、challenge 失败、requeue 等事件)。

## 文件清单

| 文件 | 资源 | 说明 |
|---|---|---|
| `cluster-issuer.yaml` | `ClusterIssuer/letsencrypt-staging` | LE staging 集群级 issuer |
| `certificates.yaml` | `Certificate` × 7 | 各 ns 一张证书,Secret 名与 Gateway 的 certificateRefs 对齐 |

## 删除自签 CA 链路的说明

原 `ingress-nginx/cert-manager/tls-resources.yaml` 的 9 个资源已全部废弃:

| 旧资源 | 新等价物 |
|---|---|
| `ClusterIssuer/selfsigned-cluster-issuer` | 删除 |
| `Certificate/k8s-ca` (中间 CA) | 删除 |
| `ClusterIssuer/k8s-ca-issuer` | 删除 |
| `Certificate/web-app-tls` (自签) | 用 LE staging 重新签 |
| `Certificate/devops-tls` (自签) | 用 LE staging 重新签 |
| `Certificate/default-tls` (自签) | 用 LE staging 重新签 |
| `Certificate/efk-tls` (自签) | 用 LE staging 重新签 |
| `Certificate/harbor-tls` (自签) | 用 LE staging 重新签 |
| `Certificate/headlamp-tls` (自签) | 在 headlamp namespace 中用 LE staging 重新签 |

`scripts/cleanup-old-ingress.sh` 会一并删除整个 `ingress-nginx/cert-manager/` 目录。