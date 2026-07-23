# Gateway API 使用说明

本目录定义共享 Istio `Gateway`，作为本地 `.k8s` 域名的统一入口。它负责监听
`18080/18443`，再通过各服务自己的 `HTTPRoute.hostnames` 分流到后端 Service。

证书不在本目录生成。HTTPS 使用的 `gateway-tls` Secret 由
`k8s_code/gateway-cert-manager` 创建。

## 整体关系

```text
浏览器 / curl
  -> hosts.k8s 把 *.k8s 解析到本机
  -> main-gateway-istio LoadBalancer Service
  -> Gateway/istio-system/main-gateway
  -> HTTPRoute(hostnames/path)
  -> Kubernetes Service
  -> Pod
```

HTTPS 证书链路：

```text
gateway-cert-manager
  -> Certificate/istio-system/gateway-tls
  -> Secret/istio-system/gateway-tls
  -> Gateway HTTPS listener certificateRefs
```

也就是说：

- `gateway-cert-manager` 负责发证书。
- `gateway` 负责开入口。
- 各服务 YAML 里的 `HTTPRoute` 负责按域名和路径分流。

## 入口端口

| Listener | 端口 | 访问格式 |
|---|---:|---|
| HTTP | `18080` | `http://<host>:18080` |
| HTTPS | `18443` | `https://<host>:18443` |

`18080/18443` 必须只由 `main-gateway-istio` 占用。不要同时应用
`ingress-nginx/ingress-nginx/nginx-port-patch.yaml`，否则两个 LoadBalancer 会争用相同的
Windows 宿主机端口。

示例：

```text
http://nacos.k8s:18080
https://nacos.k8s:18443
http://jenkins.k8s:18080/jenkins/login
https://jenkins.k8s:18443/jenkins/login
```

## 文件布局

```text
gateway/
├── gateways/
│   ├── 01-main-gateway.yaml     # 共享 Gateway，监听 18080/18443
│   └── 02-reference-grants.yaml # 可选：旧的跨 namespace TLS Secret 授权
├── patches/
│   └── envoy-max-request-bytes.yaml
└── hosts.k8s                    # 本地域名映射
```

## 前置条件

```powershell
kubectl get gatewayclass
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get pods -n istio-system
```

需要存在 `GatewayClass/istio`，并安装 Gateway API CRD。

如果要使用 HTTPS，先按 `k8s_code/gateway-cert-manager/README.md` 创建
`istio-system/gateway-tls`：

```powershell
kubectl get secret gateway-tls -n istio-system
kubectl get certificate gateway-tls -n istio-system
```

## 部署顺序

推荐顺序：

```text
1. gateway-cert-manager 生成 gateway-tls
2. gateway 创建 main-gateway
3. 应用具体服务清单，创建 Service 和 HTTPRoute
4. 写入 hosts.k8s 本地域名映射
5. curl 或浏览器验证
```

## 部署 Gateway

```powershell
kubectl apply -f .\k8s_code\gateway\gateways\01-main-gateway.yaml

kubectl get gateway main-gateway -n istio-system
kubectl get svc main-gateway-istio -n istio-system
```

期望：

- `Gateway/main-gateway` 显示 `Programmed=True`
- `Service/main-gateway-istio` 暴露 `18080` 和 `18443`

## 部署服务和 Route

每个服务的 `HTTPRoute` 放在该服务自己的资源清单里。应用服务清单时，会同时创建
Deployment、Service 和 HTTPRoute。

示例：

```powershell
kubectl apply -f .\k8s_code\nacos\nacos-k8s.yaml
kubectl apply -f .\k8s_code\jenkins\jenkins-k8s-kaniko.yaml
kubectl apply -f .\k8s_code\gitea\gitea-k8s.yaml
kubectl apply -f .\k8s_code\headlamp\headlamp-k8s.yaml
```

典型 `HTTPRoute` 关系：

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: nacos
  namespace: default
spec:
  parentRefs:
    - name: main-gateway
      namespace: istio-system
      sectionName: https
  hostnames:
    - nacos.k8s
  rules:
    - backendRefs:
        - name: nacos-service-nodeport
          port: 8848
```

`parentRefs` 指向共享 Gateway，`hostnames` 决定哪个域名进入这条路由，
`backendRefs` 指向后端 Service。

## 本地域名

以管理员身份把 `hosts.k8s` 中的映射加入 Windows hosts：

```powershell
Get-Content .\k8s_code\gateway\hosts.k8s |
  Add-Content C:\Windows\System32\drivers\etc\hosts
```

Docker Desktop 通常使用 `127.0.0.1`。如果是 kind、minikube 或其他环境，需要把
`hosts.k8s` 里的 IP 改成 Gateway LoadBalancer 的地址。

## TLS

`.k8s` 是本地域名，Let's Encrypt 不会为它签发证书。默认使用
`gateway-cert-manager` 创建的本地 CA 和 `*.k8s` 通配证书。

确认：

```powershell
kubectl get secret gateway-tls -n istio-system
kubectl get certificate gateway-tls -n istio-system
```

自签证书未加入 Windows 信任库时，浏览器会显示证书警告，`curl` 测试需要 `-k`：

```powershell
curl.exe -k -I https://nacos.k8s:18443
```

默认 `gateway-tls` 位于 `istio-system`，和 `main-gateway` 同 namespace，所以不需要
`ReferenceGrant`。只有改为引用其他 namespace 的 TLS Secret 时，才需要应用
`gateways/02-reference-grants.yaml`。

## 验证

```powershell
kubectl get gateway main-gateway -n istio-system
kubectl get httproute -A
kubectl get svc main-gateway-istio -n istio-system

curl.exe -I http://nacos.k8s:18080
curl.exe -k -I https://nacos.k8s:18443
```

如果 `Gateway` 是 `Programmed=True`，但 Windows 端口没有响应，可以重启 Docker
Desktop Kubernetes，或重新创建 Istio 自动生成的 `main-gateway-istio` Service，让
Docker Desktop 重新建立 LoadBalancer 端口转发。

## 大文件上传

Harbor、Gitea、Nexus 需要大文件上传时，可应用可选 EnvoyFilter：

```powershell
kubectl apply -f .\k8s_code\gateway\patches\envoy-max-request-bytes.yaml
```
