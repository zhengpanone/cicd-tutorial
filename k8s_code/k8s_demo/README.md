
# 1. Pod学习 -- Kubernetes 的最小单位
## 运行一个 nginx

创建文件：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-test
spec:
  containers:
    - name: nginx
      image: nginx:latest
      ports:
        - containerPort: 80
```

执行:

```shell
kubectl apply -f pod.yaml
kubectl get pods
```

访问:

```shell
kubectl port-forward nginx-test 8080:80
```

浏览器访问：

```text
http://localhost:8080
```

Pod：
- 会被删除
- 会被重建
- IP 会变
- 不能直接用于生产
- 👉 所以我们需要 Deployment。

## Deployment -- 管理副本

删除刚才的 Pod：

```shell
kubectl delete pod nginx-test
```

创建 deployment：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
```

执行：

```shell
kubectl apply -f deploy.yaml
kubectl get pods
```

你会看到 2 个 Pod。


Deployment 提供：

- 副本管理
- 自愈能力
- 滚动更新
- 回滚

测试自愈：

```shell
kubectl delete pod <某个pod>
```

它会自动重新创建。



## Service —— 解决 IP 不固定问题

创建 service：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
```

执行：

```shell
kubectl apply -f service.yaml
kubectl get svc
```

现在：

Service 提供：

- 固定访问入口
- 负载均衡



## Ingress —— 域名路由

你已经安装 ingress-nginx。

创建 ingress：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: test.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
```

编辑 `/etc/hosts`：

```text
127.0.0.1 test.local
```

访问：

```text
http://test.local
```

## ConfigMap & Secret

模拟 Spring Boot 配置：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  application.yml: |
    server:
      port: 8080
```

Secret：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
stringData:
  password: mypassword
```



## 持久化

部署 PostgreSQL：

使用 PVC：

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```



## 生产能力

### 健康检查

```yaml
livenessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
```

### HPA 自动扩容

```shell
kubectl autoscale deployment nginx-deploy --cpu-percent=50 --min=2 --max=5
```



# 2. Deployment —— 控制副本 & 滚动升级

> 企业环境 **永远不会直接使用 Pod**
>  生产环境一定用 Deployment / StatefulSet

## 本阶段目标

你要理解 4 个核心能力：

1. 副本管理（replicas）
2. 自愈能力（自动重建）
3. 滚动更新
4. 回滚

## 创建 Deployment

创建 `deploy.yaml`：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

执行：

```shell
kubectl apply -f deploy.yaml
kubectl get pods -o wide
```

你会看到 2 个 Pod。

### 理解结构

```text
Deployment
   ↓
ReplicaSet
   ↓
Pods
```

你可以查看：

```shell
kubectl get rs
```

## 测试“自愈能力”

删除一个 Pod：

```shell
kubectl delete pod <pod-name>
```

再查看：

```shell
kubectl get pods
```

它会自动创建新的。

👉 这就是控制器模式（Controller Pattern）

## 测试副本扩缩容

扩容：

```shell
kubectl scale deployment nginx-deploy --replicas=4
```

缩容：

```shell
kubectl scale deployment nginx-deploy --replicas=1
```

观察变化：

```shell
kubectl get pods
```

## 滚动升级

升级版本：

```shell
kubectl set image deployment/nginx-deploy nginx=nginx:1.26
```

观察过程：

```shell
kubectl rollout status deployment/nginx-deploy
```

你会看到：

- 先起新 Pod
- 再杀旧 Pod
- 全程不中断

这就是 Rolling Update。

## 回滚

查看历史版本：

```shell
kubectl rollout history deployment/nginx-deploy
```

回滚：

```shell
kubectl rollout undo deployment/nginx-deploy
```

## 本阶段核心认知

### 为什么不直接用 Pod？

因为：

- Pod 死了不会自动恢复
- 不能扩容
- 不能升级
- 不能回滚

### Deployment 解决了什么？

| 能力     | 生产意义   |
| -------- | ---------- |
| replicas | 高可用     |
| 自愈     | 自动恢复   |
| 滚动更新 | 无停机升级 |
| 回滚     | 版本安全   |

------

## 现在你已经掌握

- Pod 是最小单位
- Deployment 是企业标准
- Kubernetes 是声明式系统

# 3. Service —— 解决 Pod IP 会变的问题

## 本阶段目标

你要理解：

1. Pod IP 为什么不能直接用
2. Service 是什么
3. ClusterIP 工作原理
4. 负载均衡是怎么实现的

------

## 先理解一个现实问题

执行：

```
kubectl get pods -o wide
```

你会看到类似：

```
nginx-deploy-xxxxx   10.42.0.5
nginx-deploy-yyyyy   10.42.0.6
```

问题：

- 这些 IP 会变
- Pod 重建 IP 就变
- 扩容缩容都会变

👉 所以不能直接访问 Pod。

------

## 解决方案：Service

Service 提供：

- 固定虚拟 IP
- 固定 DNS 名
- 自动负载均衡

------

## 实战 1：创建 Service

创建 `service.yaml`：

```
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
```

执行：

```
kubectl apply -f service.yaml
kubectl get svc
```

你会看到：

```
nginx-service   ClusterIP   10.43.x.x
```

------

### 理解关键字段

```
selector:
  app: nginx
```

意思是：

> 自动选中所有带有 app=nginx 的 Pod

你可以验证：

```
kubectl get endpoints nginx-service
```

你会看到所有 Pod IP。

------

## 实战 2：内部访问测试

进入一个 Pod：

```
kubectl exec -it <某个pod> -- sh
```

然后：

```
wget -qO- nginx-service
```

你会成功访问。

------

### 你要理解的核心

Service 有 3 种类型：

| 类型         | 用途                 |
| ------------ | -------------------- |
| ClusterIP    | 集群内部访问（默认） |
| NodePort     | 对外暴露端口         |
| LoadBalancer | 云环境用             |

我们先用 ClusterIP。

------

## 实战 3：测试负载均衡

扩容：

```
kubectl scale deployment nginx-deploy --replicas=4
```

查看 endpoints：

```
kubectl get endpoints nginx-service
```

你会看到 4 个 IP。

Service 会：

> 随机分发流量到这些 Pod

这是 kube-proxy 实现的。

------

### 深入一点（你是后端开发）

Service 本质：

- 不是进程
- 不是容器
- 是 iptables / ipvs 规则

k3s 默认使用 iptables 模式。

------

### 现在你的架构变成

```
Client
   ↓
Service (固定IP)
   ↓
Pods (多个副本)
```

这就是微服务基础通信模型。

------

## 本阶段任务

完成：

1. 创建 Service
2. 查看 endpoints
3. 扩容到 4 副本
4. 确认 endpoints 自动更新



# 4. Ingress（域名级流量管理）

Service 解决的是 **集群内部四层转发（ClusterIP）**
 Ingress 解决的是 **集群外部七层域名流量管理（HTTP/HTTPS）**

## Ingress 在整体架构中的位置

```text
外部用户
    ↓
DNS
    ↓
Ingress Controller
    ↓
Service
    ↓
Pod
```

## Ingress 到底解决什么问题？

Service 只能做：

- IP:Port 转发
- 4 层负载均衡
- 无法按域名 / 路径分流

Ingress 可以做：

- 多域名管理
- 路径转发
- HTTPS 终止
- 证书管理
- 灰度发布
- 限流
- 重写规则

本质：**七层反向代理**

## Ingress 的核心组件

### Ingress 资源对象（规则）

只是一个规则描述文件：

```
apiVersion: networking.k8s.io/v1
kind: Ingress
```

本身不干活。

### Ingress Controller（真正干活的）

常见实现：

- NGINX, Inc. 的 **NGINX Ingress Controller**
- Traefik Labs 的 **Traefik**
- HAProxy Technologies 的 **HAProxy Ingress**
- 云厂商自带 Ingress

它监听 Ingress 资源变化，然后生成真实的：

- Nginx 配置
- 或其他代理配置

## 典型 Ingress 示例

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

意思是：

```
访问 api.example.com
    ↓
转发到 api-service
```



## 流量进入完整链路

```
浏览器访问 https://api.example.com
        ↓
DNS 解析到公网 IP
        ↓
Ingress Controller (Nginx)
        ↓
匹配 host/path 规则
        ↓
转发到 Service
        ↓
Service 负载均衡到 Pod
```





## 生产级常见能力

#### HTTPS 终止

```
tls:
  - hosts:
      - api.example.com
    secretName: tls-secret
```

证书放在 Secret 中。

------

#### 多域名

```
api.example.com   → api-service
admin.example.com → admin-service
```

------

#### 路径分流

```
/api  → api-service
/web  → web-service
```

------

#### 灰度发布（基于 Nginx）

通过 annotation：

```
nginx.ingress.kubernetes.io/canary: "true"
```

可以做：

- 按 header
- 按权重
- 按 cookie

------

## Ingress 进入流量管理阶段的判断

你可以检查：

#### 是否安装 Controller

```
kubectl get pods -n ingress-nginx
```

------

#### 是否获取到外部 IP

```
kubectl get svc -n ingress-nginx
```

看是否有：

```
EXTERNAL-IP
```

------

#### Ingress 是否生效

```
kubectl describe ingress
```

看 Events。

------

## 和前面 Service 阶段的区别

| 阶段    | 作用               |
| ------- | ------------------ |
| Pod     | 运行容器           |
| Service | 内部负载均衡       |
| Ingress | 外部域名级流量入口 |

------

## 生产架构升级路线

### 初级

```
NodePort
```

### 进阶

```
LoadBalancer Service
```

### 企业级

```
Ingress + HTTPS + 灰度 + WAF
```

------

## 如果你在生产集群里

你之前在排查滚动更新 + Service。

现在可以检查：

- 是否 Ingress 把流量导到了旧 Service
- 是否灰度规则导致流量分流异常
- 是否 ingress controller reload 失败

------

## 一句话总结

> Service 解决“进集群”
>  Ingress 解决“进系统”

------



# 5. Gateway API



# 6. Service Mesh（流量治理终极形态）



前面是：

```
Pod → Service → Ingress → Gateway API
```

那 Service Mesh 是：

```
Pod ↔ Pod 之间的流量治理系统
```

它解决的是 **集群“内部东西向流量”问题**。



## Service Mesh 是什么？

一句话：

> 把网络治理能力，从代码中抽离出来。

典型代表：

- Istio
- Linkerd



## 为什么需要 Mesh？

在微服务系统里你会遇到：

- 服务调用失败重试
- 超时控制
- 熔断
- 限流
- 金丝雀发布
- 链路追踪
- mTLS 加密
- 灰度流量控制

如果全部写在 Spring Boot 里：

- 复杂
- 难维护
- 各语言不统一

Mesh 的核心思想：

> 让 Sidecar 代理负责流量治理
>  业务只负责业务逻辑



## Mesh 架构原理

### Sidecar 模式

每个 Pod 旁边都会多一个代理容器：

```
[ app container ]
[ envoy proxy    ]
```

典型代理是 Envoy（Istio 使用）。

流量路径变成：

```
A 应用
 ↓
A sidecar
 ↓
网络
 ↓
B sidecar
 ↓
B 应用
```

所有流量都经过代理。

## Mesh 分为两部分

### 数据面（Data Plane）

- Envoy sidecar
- 负责转发流量

### 控制面（Control Plane）

例如：

- Istio 的 istiod

负责：

- 下发流量规则
- 下发证书
- 管理配置



## Mesh 能解决什么？

### 熔断

```
当 B 服务错误率 > 50%
自动拒绝流量
```

------

### 超时控制

```
调用 B 最多 2 秒
超时立即失败
```

------

### 重试

```
失败自动重试 3 次
```

------

### 灰度发布

可以按：

- Header
- Cookie
- 权重
- 用户 ID

做精准流量分发。

------

### mTLS（零信任）

服务之间自动加密通信



## 和 Gateway API 的关系

Gateway API 解决：

```
南北向流量（外部进集群）
```

Service Mesh 解决：

```
东西向流量（服务之间）
```

在生产里常见架构：

```
            外部流量
                ↓
        Gateway API
                ↓
        Service Mesh
                ↓
           各微服务
```

很多 Mesh（例如 Istio）已经支持 Gateway API 作为入口规范。



## 什么时候需要 Mesh？

| 场景         | 是否需要 |
| ------------ | -------- |
| 单体应用     | 不需要   |
| 3~5 个微服务 | 不一定   |
| 20+ 微服务   | 建议     |
| 多语言系统   | 强烈建议 |
| 金融/零信任  | 必须     |

## Mesh 的代价

⚠️ 不是银弹。

代价包括：

- 每个 Pod 多一个 sidecar（资源消耗）
- 网络复杂度上升
- 调试难度提高
- 学习成本高

------

## Mesh 升级路线建议（现实版）

很多团队正确的演进路径是：

```
1️⃣ Service
2️⃣ Ingress
3️⃣ Gateway API
4️⃣ 局部 Mesh
5️⃣ 全局 Mesh
```



## 总结

> Gateway 管入口
>  Mesh 管内部
>  Service 只是基础转发

# Mesh实战

主流选择：

- ⭐⭐⭐⭐ Istio（功能最全，生态最强）
- ⭐⭐⭐ Linkerd（轻量，简单）
- ⭐⭐ 云厂商自带 Mesh

如果你：

- 多语言（Java + Go + Rust + Python）
- 未来可能零信任
- 需要高级流量治理

👉 建议：Istio

## 企业级架构

不要全量一刀切。

建议架构：

```
                 外部流量
                      ↓
               Gateway API
                      ↓
              Ingress Gateway
                      ↓
         ┌──────── Service Mesh ────────┐
         ↓                               ↓
      核心服务组                      普通服务组
         ↓                               ↓
      数据库                         缓存 / MQ
```

## 升级策略（千万不要一次性全开）

### 第一步：只上入口 Mesh

部署 Istio，只使用：

```
Ingress Gateway
```

先替换原 Ingress。

此时：

- 外部流量由 Mesh 控制
- 内部流量还未 sidecar

风险最低。

### 第二步：核心服务注入 Sidecar

选择 3~5 个核心微服务：

```
kubectl label namespace core istio-injection=enabled
```

让它们进 Mesh。

测试：

- 延迟
- CPU 增加情况
- 调用链是否正常

------

### 第三步：逐步扩展

每周扩一个业务域。

不要全量注入。



## 多语言系统为什么 Mesh 更重要？

假设你有：

- Spring Boot
- Go
- Rust
- Python

如果不用 Mesh：

- 每种语言都要实现重试
- 每种语言都要实现熔断
- 每种语言都要接 tracing

用 Mesh：

```
全部统一由 Envoy 处理
```

业务代码不用改。



## 性能问题

现实数据（生产平均）：

- 每个 sidecar 占用 50~100MB 内存
- 延迟增加 2~5ms

如果：

- 单机 32GB 内存
- 节点充足

完全可接受。

但如果是小集群：

⚠️ 不建议全开。



## 组合方案（非常实用）

你现在已经在研究：

- Gateway API

推荐终态：

```
Gateway API + Istio
```

很多新版本 Istio 已支持 Gateway API 作为标准入口。

这样：

- Gateway API 做标准资源
- Istio 做流量执行

## 现实中的“最佳实践结构”

对于 30+ 服务，我推荐：

```
1️⃣ 网关层（Mesh Ingress）
2️⃣ 核心业务域（Mesh）
3️⃣ 边缘服务（可不 Mesh）
4️⃣ 数据层不注入
```

不是所有 Pod 都必须 Sidecar。



























