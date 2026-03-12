# Sentinel on Kubernetes

Alibaba Sentinel 是一个 **分布式系统流量治理组件**，提供：

* 流量控制（限流）
* 熔断降级
* 系统保护
* 热点参数限流
* 实时监控

Sentinel 通过 **Dashboard 控制台**对应用进行统一管理。

---

# 部署步骤

```bash
# 1. 部署 Sentinel Dashboard
kubectl apply -f sentinel-k8s.yaml

# 2. 查看部署状态
kubectl get all -l app=sentinel

# 3. 查看 Pod 日志
kubectl logs -l app=sentinel -f

# 4. 等待 Pod 就绪
kubectl wait --for=condition=ready pod -l app=sentinel --timeout=300s
```

---

# 访问 Sentinel Dashboard

```bash
# 获取节点 IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "Sentinel Dashboard: http://${NODE_IP}:30880"
echo "用户名: sentinel"
echo "密码: sentinel"
```

---

## 浏览器访问

```
http://<NODE_IP>:30880
```

默认登录：

```
username: sentinel
password: sentinel
```

---

# 监控启动进度

```bash
# 实时查看日志
kubectl logs -l app=sentinel -f

# 查看 Pod 状态
watch kubectl get pods -l app=sentinel

# 查看 Pod 详情
kubectl describe pod -l app=sentinel
```

---

# Sentinel 启动阶段

```
1. 容器启动
2. Java 服务初始化
3. Sentinel Dashboard 启动
4. Web 控制台启动
5. 服务就绪 ✓
```

---

# Spring Boot 接入 Sentinel

如果你的服务是 **Spring Boot 应用**，需要引入 Sentinel 依赖。

## Maven 依赖

```xml
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-sentinel</artifactId>
</dependency>
```

---

## Spring Boot 配置

```yaml
spring:
  cloud:
    sentinel:
      transport:
        dashboard: sentinel-dashboard:8080
```

或者：

```yaml
spring:
  cloud:
    sentinel:
      transport:
        dashboard: NODE_IP:30880
```

---

# Sentinel 功能说明

## 1 流量控制（限流）

可以限制接口 QPS：

```
资源: /api/order
阈值: 100 QPS
策略: 快速失败
```

---

## 2 熔断降级

当服务异常比例过高时自动熔断：

```
异常比例 > 50%
持续时间: 10 秒
```

---

## 3 热点参数限流

针对 **特定参数值**限流：

```
接口: /api/product
参数: productId
productId=1 限制 10 QPS
```

---

## 4 系统保护

防止系统资源耗尽：

* CPU 使用率
* Load
* 并发线程数

---

# 查看接入应用

当 Spring Boot 服务启动并调用接口后，会自动出现在：

```
Sentinel Dashboard -> 机器列表
```

如果没有出现：

1. 确认应用访问过接口
2. 确认 Sentinel 配置正确
3. 查看客户端日志

---

# 日志查看

```bash
# 查看 Dashboard 日志
kubectl logs -l app=sentinel --tail=100 -f
```

---

# 常用操作

## 查看 Pod

```bash
kubectl get pods -l app=sentinel
```

---

## 查看 Service

```bash
kubectl get svc sentinel-dashboard
```

---

## 查看资源

```bash
kubectl get all -l app=sentinel
```

---

# 扩展和优化

## 增加资源

```bash
kubectl edit deployment sentinel-dashboard
```

增加资源：

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```

---

## 查看资源使用

```bash
kubectl top pods -l app=sentinel
```

---

# 故障排查

## 查看 Pod 详情

```bash
kubectl describe pod -l app=sentinel
```

---

## 查看事件

```bash
kubectl get events --sort-by='.lastTimestamp' | grep sentinel
```

---

## 进入容器调试

```bash
POD_NAME=$(kubectl get pod -l app=sentinel -o jsonpath='{.items[0].metadata.name}')

kubectl exec -it $POD_NAME -- sh
```

---

# 常见问题

## 1 Dashboard 无法访问

检查 Service：

```bash
kubectl get svc sentinel-dashboard
```

应该看到：

```
8080:30880/TCP
```

---

## 2 应用没有显示

Sentinel 需要 **客户端主动上报**：

* Spring Boot 服务必须引入 Sentinel 依赖
* 必须访问接口产生流量

---

## 3 Dashboard 启动失败

查看日志：

```bash
kubectl logs -l app=sentinel
```

常见原因：

* 内存不足
* Java 启动失败
* 端口冲突

---

# 安全配置

## 修改默认密码

进入 Dashboard：

```
系统管理 -> 用户管理
```

修改默认账号密码。

---

# 清理资源

```bash
kubectl delete -f sentinel-k8s.yaml
```

---

如果你愿意，我可以再给你 **一个企业级 Sentinel + Kubernetes 架构**（非常常见）：

包括：

* Sentinel Dashboard
* **Redis / Nacos 规则持久化**
* **Spring Cloud Gateway 限流**
* **多副本 Dashboard**
* **Prometheus + Grafana 监控**
* **Kubernetes Ingress**

基本就是 **生产环境微服务限流标准架构**。
