# Gateway API 使用说明

本项目使用一个共享的 Istio `Gateway` 作为所有本地域名的统一入口。每个服务的
`HTTPRoute` 与该服务的 Deployment、Service 放在同一份资源清单中。

不会为每个服务分别创建 `Gateway`。在 Docker Desktop 中，多个 LoadBalancer
无法同时占用相同的宿主机端口；共享 Gateway 才能让所有域名同时使用
`18080/18443`，再由 `HTTPRoute.hostnames` 分流。

## 入口端口

| Listener | 端口 | 访问格式 |
|---|---:|---|
| HTTP | `18080` | `http://<host>:18080` |
| HTTPS | `18443` | `https://<host>:18443` |

`18080/18443` 必须只由 `main-gateway-istio` 占用。不要同时应用
`ingress-nginx/ingress-nginx/nginx-port-patch.yaml`，否则两个 LoadBalancer
会争用相同的 Windows 宿主机端口。

例如：

```text
http://jenkins.k8s:18080/jenkins/login
https://jenkins.k8s:18443/jenkins/login
http://gitea.k8s:18080/
https://gitea.k8s:18443/
```

## 文件布局

```text
gateway/
├── gateways/
│   ├── main-gateway.yaml       # 共享 Gateway，监听 18080/18443
│   └── reference-grants.yaml   # 允许 Gateway 跨 namespace 引用 TLS Secret
├── patches/
│   └── envoy-max-request-bytes.yaml
└── hosts.k8s                   # 本地域名映射
```

HTTPRoute 已放入对应服务清单，例如：

| 服务 | 资源清单 |
|---|---|
| Jenkins | `jenkins/jenkins-k8s-kaniko.yaml` |
| Gitea | `gitea/gitea-k8s.yaml` |
| Headlamp | `headlamp/headlamp-k8s.yaml` |
| Harbor | `harbor/harbor-k8s.yaml` |
| Kibana | `kibana/kibana-k8s.yaml` |
| Elasticsearch | `elasticsearch/elasticsearch-k8s.yaml` |
| Nacos | `nacos/nacos-k8s.yaml` |
| Kafka UI | `kafka/kafka-k8s.yaml` |
| Grafana | `grafana/grafana-k8s.yaml` |
| Loki | `loki/loki-k8s.yaml` |

其余 Route 也遵循相同规则，位于后端 Service 所在的 YAML 中。

## 前置条件

```powershell
kubectl get gatewayclass
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get pods -n istio-system
```

需要存在 `GatewayClass/istio`，并安装 Gateway API CRD。

## 部署 Gateway

```powershell
kubectl apply -f .\k8s_code\gateway\gateways\reference-grants.yaml
kubectl apply -f .\k8s_code\gateway\gateways\main-gateway.yaml

kubectl get gateway main-gateway -n istio-system
kubectl get svc main-gateway-istio -n istio-system
kubectl get svc -A
```

期望 `main-gateway-istio` Service 暴露 `18080` 和 `18443`。

## 部署服务和 Route

应用某个服务清单时，会同时创建该服务的 HTTPRoute：

```powershell
kubectl apply -f .\k8s_code\jenkins\jenkins-k8s-kaniko.yaml
kubectl apply -f .\k8s_code\gitea\gitea-k8s.yaml
kubectl apply -f .\k8s_code\headlamp\headlamp-k8s.yaml
kubectl apply -f .\k8s_code\harbor\harbor-k8s.yaml
```

Jenkins 还需要先创建 kubeconfig Secret：

```powershell
kubectl create namespace devops --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic kubeconfig-secret `
  -n devops `
  --from-file=config=$env:USERPROFILE\.kube\config `
  --dry-run=client -o yaml | kubectl apply -f -
```

## 本地域名

以管理员身份把 `hosts.k8s` 中的映射加入 Windows hosts：

```powershell
Get-Content .\k8s_code\gateway\hosts.k8s |
  Add-Content C:\Windows\System32\drivers\etc\hosts
```

## TLS

`.k8s` 是本地域名，Let's Encrypt 不会为它签发证书。HTTPS 本地测试应使用自签
证书，并确保 Gateway 引用的 `devops/devops-tls` Secret 存在：

```powershell
kubectl get secret devops-tls -n devops
kubectl get referencegrant -A
```

自签证书未加入 Windows 信任库时，浏览器会显示证书警告，`curl` 测试需要 `-k`。

## 验证

```powershell
kubectl get gateway main-gateway -n istio-system
kubectl get httproute -A

curl.exe -I http://jenkins.k8s:18080/jenkins/login
curl.exe -k -I https://jenkins.k8s:18443/jenkins/login
```

如果 Gateway 显示 `Programmed=True`，但 Windows 端口没有响应，重启 Docker
Desktop Kubernetes，或重新创建 Istio 自动生成的 `main-gateway-istio` Service，
让 Docker Desktop 重新建立 LoadBalancer 端口转发。

## 大文件上传

Harbor、Gitea、Nexus 需要大文件上传时，可应用可选 EnvoyFilter：

```powershell
kubectl apply -f .\k8s_code\gateway\patches\envoy-max-request-bytes.yaml
```
