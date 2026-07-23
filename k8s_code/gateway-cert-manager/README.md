# Gateway TLS 与 cert-manager

本目录负责为共享 Istio Gateway 生成 HTTPS 证书。它不负责流量入口，也不创建
`HTTPRoute`；它的最终产物是 `istio-system/gateway-tls` 这个 TLS Secret。

`gateway` 目录里的 `main-gateway` 会直接引用这个 Secret：

```text
gateway-cert-manager
  cert-manager.yaml
    -> ClusterIssuer/local-self-signed
    -> Certificate/local-k8s-ca
    -> ClusterIssuer/local-k8s-ca-issuer
    -> Certificate/gateway-tls
    -> Secret/istio-system/gateway-tls

gateway
  Gateway/istio-system/main-gateway
    -> HTTPS listener 18443
    -> certificateRefs: Secret/gateway-tls
```

项目默认使用本地 `.k8s` 域名，所以默认方案是本地 CA 签发一张 `*.k8s`
通配证书。Let's Encrypt 不会为 `.k8s`、`.local` 这类本地域名签发证书。

## 和 gateway 的关系

- `gateway-cert-manager`：负责安装 cert-manager、创建本地 CA、签发 `gateway-tls`。
- `gateway`：负责创建共享 `Gateway/main-gateway`，监听 `18080/18443`。
- 各服务清单：负责创建自己的 `HTTPRoute`，通过 `hostnames` 接入 `main-gateway`。

因此部署顺序通常是：

```text
cert-manager 和证书链
  -> gateway/main-gateway
  -> 服务清单中的 HTTPRoute
  -> hosts.k8s 本地域名映射
```

`gateway-tls` 和 `main-gateway` 都在 `istio-system` namespace，所以默认不需要
`ReferenceGrant`。只有改回“Gateway 跨 namespace 引用其他 Secret”的方案时，才需要
`gateway/gateways/02-reference-grants.yaml`。

## 前置条件

- 已安装 Gateway API CRD
- 已安装 Istio，并存在 `GatewayClass/istio`
- `istio-system` namespace 已存在
- 集群可以拉取 cert-manager 镜像

可以先检查：

```powershell
kubectl get gatewayclass
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get pods -n istio-system
```

## 文件清单

| 文件 | 资源 | 说明 |
|---|---|---|
| `cert-manager.yaml` | cert-manager v1.21.0 | cert-manager 安装清单 |
| `01-self-signed-issuer.yaml` | `ClusterIssuer/local-self-signed` | 只用于引导本地 CA |
| `02-local-ca.yaml` | `Certificate/local-k8s-ca` | 在 `cert-manager` namespace 创建本地 CA |
| `03-local-ca-issuer.yaml` | `ClusterIssuer/local-k8s-ca-issuer` | 使用本地 CA 签发服务端证书 |
| `04-wildcard-k8s-certificate.yaml` | `Certificate/gateway-tls` | 在 `istio-system` 创建 `gateway-tls` Secret |
| `examples/letsencrypt-staging/` | 可选 ACME 示例 | 只用于真实公网域名，不用于 `.k8s` |

## 部署本地证书链

以下命令从仓库根目录执行。

```powershell
# 1. 安装 cert-manager
kubectl apply -f .\k8s_code\gateway-cert-manager\cert-manager.yaml
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=180s
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=180s
kubectl wait --for=condition=Available deployment/cert-manager-cainjector -n cert-manager --timeout=180s

# 2. 创建自签名引导 issuer 和本地 CA
kubectl apply -f .\k8s_code\gateway-cert-manager\01-self-signed-issuer.yaml
kubectl apply -f .\k8s_code\gateway-cert-manager\02-local-ca.yaml
kubectl wait --for=condition=Ready certificate/local-k8s-ca -n cert-manager --timeout=120s

# 3. 创建由本地 CA 支持的 ClusterIssuer
kubectl apply -f .\k8s_code\gateway-cert-manager\03-local-ca-issuer.yaml
kubectl wait --for=condition=Ready clusterissuer/local-k8s-ca-issuer --timeout=120s

# 4. 为共享 Gateway 创建 *.k8s 通配证书
kubectl apply -f .\k8s_code\gateway-cert-manager\04-wildcard-k8s-certificate.yaml
kubectl wait --for=condition=Ready certificate/gateway-tls -n istio-system --timeout=120s
```

如果 cert-manager 已经安装并 Ready，可以从第 2 步开始。

## 接入 Gateway

证书 Ready 后，再应用共享 Gateway：

```powershell
kubectl apply -f .\k8s_code\gateway\gateways\01-main-gateway.yaml
kubectl get certificate gateway-tls -n istio-system
kubectl get secret gateway-tls -n istio-system
kubectl get gateway main-gateway -n istio-system
```

期望结果：

- `Certificate/gateway-tls` 为 `Ready=True`
- `Secret/gateway-tls` 类型为 `kubernetes.io/tls`
- `Gateway/main-gateway` 为 `Programmed=True`

## 访问示例

服务自己的 `HTTPRoute` 创建后，可以通过共享 Gateway 访问：

```powershell
curl.exe -I http://nacos.k8s:18080
curl.exe -k -I https://nacos.k8s:18443
curl.exe -k -I https://jenkins.k8s:18443/jenkins/login
```

`-k` 只用于跳过本地 CA 的信任校验。浏览器访问 HTTPS 时，如果还没有信任本地
CA，会显示证书警告。

## 信任本地 CA

如果希望 Windows 浏览器不再提示证书风险，可以导出本地 CA 公共证书并加入受信任
根证书。只导出 `ca.crt`，不要导出或分享 Secret 中的私钥。

管理员 PowerShell：

```powershell
$caData = kubectl get secret local-k8s-ca -n cert-manager -o jsonpath="{.data.ca\.crt}"
[System.IO.File]::WriteAllBytes(".\local-k8s-ca.crt", [Convert]::FromBase64String($caData))
certutil.exe -addstore -f Root .\local-k8s-ca.crt
```

## 可选：Let's Encrypt staging

`examples/letsencrypt-staging/` 只适用于真实公网域名，并且 HTTP-01 challenge 必须能
从公网访问到 Gateway 的 80 端口。

使用前必须：

1. 把 `examples/letsencrypt-staging/cluster-issuer.yaml` 中的邮箱替换为真实邮箱。
2. 把示例证书中的 `.k8s` 主机名替换为真实域名。
3. 确认公网 DNS 已解析到 Gateway，并且 HTTP listener 对公网开放 80 端口。

```powershell
kubectl apply -f .\k8s_code\gateway-cert-manager\examples\letsencrypt-staging\cluster-issuer.yaml
kubectl apply -f .\k8s_code\gateway-cert-manager\examples\letsencrypt-staging\certificates.yaml
kubectl get certificate -A -w
```

注意：

- HTTP-01 不能签发 wildcard 证书，真实域名的 wildcard 需要 DNS-01 solver。
- 不要把 `letsencrypt-staging` 和 `local-k8s-ca-issuer` 同时用于同一个 Certificate。
- 本地 `.k8s` 默认链路不依赖 `examples/letsencrypt-staging/`。

## 排查

```powershell
kubectl describe certificate gateway-tls -n istio-system
kubectl get certificaterequest -n istio-system
kubectl get clusterissuer local-k8s-ca-issuer
kubectl logs -n cert-manager deploy/cert-manager --tail=100
```

如果看到旧的 `letsencrypt-staging` Certificate 一直 Pending，它们属于旧的 ACME
配置，不影响 `istio-system/gateway-tls`。确认不再需要这些旧资源后，再按 namespace
删除对应的 Certificate。
