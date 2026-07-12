# Gateway API 迁移说明(Ingress → Istio Gateway)

本目录是把项目原 ingress-nginx 全部迁移到 **Kubernetes Gateway API**(`gateway.networking.k8s.io/v1`)后的统一入口。Istio `istio-ingressgateway` 作为 GatewayClass `istio` 的实现。

## 1. 文件结构

```
gateway/
├── gateways/
│   ├── main-gateway.yaml       # 1 个 Gateway 资源(istio-system),HTTP+HTTPS listener
│   └── reference-grants.yaml   # 7 个 ReferenceGrant,授权跨 ns 引用 TLS Secret
├── routes/
│   ├── web-app.yaml                # 3 条 HTTPRoute(原 web-app-ingress.yaml)
│   ├── devops.yaml                 # 2 条(jenkins, gitea)
│   ├── default-infra.yaml          # 14 条(default ns 13 + kafka-ui)
│   ├── elk.yaml                    # 2 条(kibana, elasticsearch)
│   ├── harbor.yaml                 # 1 条(含 backendRequest=600s)
│   ├── kubernetes-dashboard.yaml   # 1 条 headlamp(该 namespace 的历史 Ingress)
│   ├── headlamp.yaml               # 1 条 headlamp(headlamp ns 的实际部署)
│   └── tutorials-no-tls.yaml       # 4 条无 TLS 演示(nginx/rabbitmq/nexus/test)
├── patches/
│   └── envoy-max-request-bytes.yaml  # 放开大文件上传缓冲上限(harbor/gitea/nexus)
└── hosts.k8s                       # 28 个 host 的本地 hosts 映射清单
```

合计 **28 条 HTTPRoute**,与原 28 条 Ingress 一一对齐(web-app 两份冗余副本合并、headlamp 完整保留 2 条)。

## 2. 前置依赖

| 组件 | 版本要求 | 说明 |
|---|---|---|
| Kubernetes | 1.27+ | Gateway API GA |
| Istio | 1.21+ | `URLRewrite` / `RequestRedirect` filter 需要 v1 |
| cert-manager | 1.14+ | `http01.gateway` solver 需要 v1.14 |
| Gateway API CRD | v1.0+ | `kubectl get crd gateways.gateway.networking.k8s.io` |

```bash
# 验证集群已就绪
kubectl get gatewayclass                          # 确认有 istio
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get pods -n istio-system -l app=istiod
kubectl get pods -n cert-manager
```

## 3. 必须先做的:替换 `k8s` 占位符

所有 host 都用了占位 `k8s`(例如 `my-gin-app.k8s`)。**LE staging 必须用真实可解析域名**,否则证书申请会永久 Pending。

```bash
# 1. 准备你拥有的真实可解析域名后缀(用于 DNS 解析到 istio-ingressgateway)
export DOMAIN_SUFFIX=dev.example.com

# 2. 替换 gateway/ 下所有 HTTPRoute 的 hostnames
find gateway -name '*.yaml' -exec sed -i "s/k8s/${DOMAIN_SUFFIX}/g" {} +

# 3. 替换 gateway-cert-manager/ 下所有 Certificate 的 dnsNames
find gateway-cert-manager -name '*.yaml' -exec sed -i "s/k8s/${DOMAIN_SUFFIX}/g" {} +

# 4. 别忘了把 gateway-cert-manager/cluster-issuer.yaml 里的
#    email: your-email@example.com 替换成你的邮箱
```

## 4. 部署顺序

```bash
# 1. cert-manager Issuer + Certificate(等待证书签发)
kubectl apply -f gateway-cert-manager/cluster-issuer.yaml
kubectl apply -f gateway-cert-manager/certificates.yaml
kubectl get certificate -A           # 期望全部 Ready(若一直 Pending,域名没解析到网关)

# 2. Gateway + ReferenceGrant
kubectl apply -f gateway/gateways/main-gateway.yaml
kubectl apply -f gateway/gateways/reference-grants.yaml
kubectl get gateway -n istio-system
kubectl get referencegrant -A

# 3. HTTPRoute
kubectl apply -f gateway/routes/

# 4.(可选)放开大文件上传缓冲上限(harbor / gitea / nexus)
kubectl apply -f gateway/patches/envoy-max-request-bytes.yaml

# 5.(本地测试)追加 hosts 映射,把 *.k8s 指向网关
#    Windows(管理员 PowerShell):
#      Get-Content gateway\hosts.k8s | Add-Content C:\Windows\System32\drivers\etc\hosts
#    Linux/macOS:
#      sudo sh -c 'cat gateway/hosts.k8s >> /etc/hosts'

# 6. 删除旧 Ingress 文件(在新 Gateway 全部就绪后)
#    Linux/macOS:  bash scripts/cleanup-old-ingress.sh
#    Windows:      powershell -ExecutionPolicy Bypass -File .\scripts\cleanup-old-ingress.ps1
bash scripts/cleanup-old-ingress.sh
```

## 5. 已知 annotation 翻译差异

| 原 nginx-ingress annotation | Gateway API 翻译 | 备注 |
|---|---|---|
| `app-root: /nacos` | `RequestRedirect` filter(`/` → 308 → `/nacos/`) | 见 `routes/default-infra.yaml:nacos` |
| `rewrite-target: /` | `URLRewrite.ReplacePrefixMatch /`→`/`(noop) | 见 `routes/tutorials-no-tls.yaml:rabbitmq-demo` |
| `proxy-read-timeout: "600"` | `timeouts.backendRequest: 600s` | 见 `routes/harbor.yaml` |
| `proxy-send-timeout: "600"` | 同上(Gateway API 不区分读写) | 同上 |
| `proxy-body-size: "0"` | **无直接对应** → 需 `EnvoyFilter` 调大 `max_request_bytes`,模板见下文 | harbor / gitea / nexus 受影响 |
| `ingressClassName: public` | **不再需要**,统一走 main-gateway | rabbitmq 已迁移 |
| `nginx.ingress.kubernetes.io/ssl-redirect: "false"` | Gateway 默认不重定向,**无需翻译** | 所有路由 |

### proxy-body-size=0 → EnvoyFilter 补丁(harbor / gitea / nexus)

Istio ingress gateway 默认对请求体大小【不做硬性限制】(流式转发不受缓冲上限约束)。真正可能截断大上传的是 per-connection 缓冲上限(默认 1MiB),在需要完整缓冲请求时才生效。

清单已备好:`gateway/patches/envoy-max-request-bytes.yaml`,把 http(80) 与 https(443) 两个 listener 的 `per_connection_buffer_limit_bytes` 调大到 1GiB。

```bash
kubectl apply -f gateway/patches/envoy-max-request-bytes.yaml

# 验证 listener 缓冲上限已生效
istioctl proxy-config listener deploy/istio-ingressgateway -n istio-system
```

适用:`harbor`(镜像推送,https)、`gitea`(git push,http)、`nexus`(制品上传,http)。

> ⚠️ `workloadSelector.labels.istio: ingressgateway` 需按你的网关实际 label 调整:
> `kubectl get pods -n istio-system --show-labels | grep gateway`

### app-root 与 Istio 兼容性

`nacos` 用了两条规则:
- 规则 1:PathPrefix `/` 命中后通过 `RequestRedirect` 308 重定向到 `/nacos/`
- 规则 2:PathPrefix `/nacos` 命中后直接转发到后端

避免 Gateway API 缺乏"仅根路径匹配"语法导致误伤其它子路径。

## 6. 历史包袱(用户需决定是否修复)

- **两条 headlamp 共存**:原 `infra-ingress.yaml` 声明 `namespace: kubernetes-dashboard`,但实际 Deployment/Service 在 `headlamp` namespace。两份 Ingress 共用 Secret 名 `headlamp-tls`(各自 ns 一份)。本迁移完整保留为两条 HTTPRoute(`gateway/routes/kubernetes-dashboard.yaml` 与 `gateway/routes/headlamp.yaml`),host 第二个改为 `headlamp-k8s.k8s` 以避免冲突。要收敛到一份由用户自行决定。
- **web-app 路由冗余**:原 `web-app-ingress.yaml`(顶层)与 `ingress-nginx/web-app-ingress/web-app-ingress.yaml` 是同一份路由的重复声明。迁移后只在 `gateway/routes/web-app.yaml` 保留一份。
- **`ingress-nginx` Controller 目录**:保留 `ingress-nginx/ingress-nginx/` 的 Controller 部署相关文件(本迁移不卸载),若已完全切换到 Istio,可后续单独删除。

## 7. 回滚

```bash
# 删除 Gateway 资源(会自动级联删除 HTTPRoute 引用)
kubectl delete gateway main-gateway -n istio-system
kubectl delete referencegrant -A
kubectl delete -f gateway/routes/

# 复原旧 Ingress(若还没运行 cleanup-old-ingress.sh)
git checkout HEAD -- web-app-ingress.yaml infra-ingress.yaml k8s_demo/ingress.yaml \
  ingress-nginx/web-app-ingress/ ingress-nginx/cert-manager/
```

## 8. 验证

```bash
# 资源数量
kubectl get gateway -n istio-system                  # 1
kubectl get referencegrant -A | wc -l               # 7
kubectl get httproute -A | wc -l                    # 28
kubectl get certificate -A | wc -l                  # 7

# Ingress 残留检查
grep -rn "^kind: Ingress$" k8s_code/                # 应为 0(除已注释的)
```

## 9. 易踩坑

1. **`gatewayClassName: istio` 名字可能不是 `istio`** —— `kubectl get gatewayclass` 查看实际名字,可能是 `istio-waypoint` / `istio-east-west` 等,按需修改 `gateways/main-gateway.yaml`。
2. **ReferenceGrant 必须在 Secret 所在 ns,不是 Gateway 所在 ns** —— 本迁移已正确放置,但若复制模板时容易反。
3. **`parentRefs.sectionName` 必须写 `http` 或 `https`** —— 不写则 HTTPRoute 不知道绑哪个 listener。
4. **LE staging 证书浏览器默认不信任** —— `curl -k` 或手动信任 ISRG Root X1(staging 用假根)。
5. **`setup-tls.sh` 已废弃** —— 自签 CA 路径不再需要。脚本保留供本地离线场景参考,不要在 LE 链路里跑。