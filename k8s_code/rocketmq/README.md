# RocketMQ on Kubernetes（生产级部署文档）

---

# 一、架构说明

## 1.1 架构组件

```
                ┌──────────────────────┐
                │     Dashboard UI     │
                │       :8080          │
                └──────────┬───────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                                     │
┌───────────────┐                  ┌────────────────┐
│   Broker      │ <──────────────> │   Broker Slave │
│ (Master)      │     HA复制        │                │
└──────┬────────┘                  └──────┬─────────┘
       │                                  │
       └──────────────┬───────────────────┘
                      │
             ┌────────────────┐
             │ NameServer 集群 │
             │ (2副本)        │
             └────────────────┘
```

---

## 1.2 组件说明

| 组件            | 说明       |
| ------------- | -------- |
| NameServer    | 路由中心，无状态 |
| Broker Master | 写入节点     |
| Broker Slave  | 数据同步节点   |
| Dashboard     | 管理界面     |

---

# 二、部署步骤

```bash
# 1. 部署所有资源
kubectl apply -f rocketmq-k8s.yaml

# 2. 查看资源
kubectl get all -l app=rocketmq

# 3. 查看 PV/PVC
kubectl get pv,pvc | grep rocketmq

# 4. 查看日志
kubectl logs -l app=rocketmq -f

# 5. 等待就绪
kubectl wait --for=condition=ready pod -l app=rocketmq --timeout=300s
```

---

# 三、访问方式

## 3.1 Dashboard

```bash
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "Dashboard: http://${NODE_IP}:30880"
```

浏览器访问：

```
http://<NODE_IP>:30880
```

---

## 3.2 Broker 连接地址

```text
rocketmq-broker:10911
```

或：

```text
<node-ip>:30911   # NodePort（如果配置）
```

---

## 3.3 NameServer 地址

```text
rocketmq-nameserver-0.rocketmq-nameserver:9876
rocketmq-nameserver-1.rocketmq-nameserver:9876
```

---

# 四、存储结构

## 4.1 宿主机目录

```
/opt/dockerstore/rocketmq/
├── broker-0   # Master
└── broker-1   # Slave
```

---

## 4.2 容器内部

```
/home/rocketmq/store
├── commitlog
├── consumequeue
└── index
```

---

# 五、Broker 主从机制

## 5.1 配置说明

| 参数         | Master       | Slave    |
| ---------- | ------------ | -------- |
| brokerName | broker-a     | broker-a |
| brokerId   | 0            | 1        |
| brokerRole | ASYNC_MASTER | SLAVE    |

---

## 5.2 同步机制

* Master 写入
* Slave 拉取同步
* 支持：

  * ASYNC_MASTER（默认）
  * SYNC_MASTER（强一致）

---

# 六、验证集群状态

## 6.1 查看 Broker

```bash
kubectl exec -it <broker-pod> -- sh
mqadmin clusterList -n rocketmq-nameserver:9876
```

---

## 6.2 查看 Topic

```bash
mqadmin topicList -n rocketmq-nameserver:9876
```

---

## 6.3 查看消费组

```bash
mqadmin consumerProgress -n rocketmq-nameserver:9876
```

---

# 七、常用操作

## 7.1 创建 Topic

```bash
mqadmin updateTopic \
-n rocketmq-nameserver:9876 \
-c DefaultCluster \
-t test-topic
```

---

## 7.2 删除 Topic

```bash
mqadmin deleteTopic \
-n rocketmq-nameserver:9876 \
-c DefaultCluster \
-t test-topic
```

---

## 7.3 发送测试消息

```bash
sh tools.sh org.apache.rocketmq.example.quickstart.Producer
```

---

# 八、日志与调试

## 8.1 查看日志

```bash
kubectl logs -l app=rocketmq-broker-master -f
kubectl logs -l app=rocketmq-broker-slave -f
```

---

## 8.2 进入容器

```bash
kubectl exec -it <pod-name> -- sh
```

---

## 8.3 端口检查

```bash
ss -lntp
```

---

# 九、扩展与优化

## 9.1 调整资源

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "2Gi"
  limits:
    cpu: "2"
    memory: "4Gi"
```

---

## 9.2 高可用建议

* NameServer ≥ 2
* Broker 主从部署在不同节点
* 使用 `nodeSelector` 或 `affinity`

---

## 9.3 刷盘策略

```properties
flushDiskType=SYNC_FLUSH   # 强一致（推荐生产）
```

---

## 9.4 关闭自动创建

```properties
autoCreateTopicEnable=false
```

---

# 十、故障排查

## 10.1 Broker 未注册

```bash
mqadmin clusterList -n ...
```

原因：

* NameServer 地址错误
* 网络不通

---

## 10.2 数据未持久化

检查：

```bash
kubectl get pvc
```

必须：

```
STATUS = Bound
```

---

## 10.3 主从不同步

检查：

```bash
mqadmin brokerStatus -n ...
```

关注：

* slaveFallBehindMuch

---

# 十一、备份与恢复

## 11.1 备份

```bash
tar -czf rocketmq-backup-$(date +%Y%m%d).tar.gz \
/opt/dockerstore/rocketmq
```

---

## 11.2 恢复

```bash
tar -xzf rocketmq-backup-xxx.tar.gz -C /opt/dockerstore/
```

重启：

```bash
kubectl rollout restart statefulset rocketmq-broker-master
kubectl rollout restart statefulset rocketmq-broker-slave
```

---

# 十二、清理资源

```bash
kubectl delete -f rocketmq-k8s.yaml
```

删除数据：

```bash
rm -rf /opt/dockerstore/rocketmq
```

⚠️ 数据不可恢复

---

# 十三、生产增强（建议）

## ✔ 必做

* 使用 `SYNC_MASTER`
* 关闭自动创建 Topic
* 设置 JVM 参数
* 配置资源限制

## ✔ 推荐

* Ingress + 域名
* TLS 加密
* Prometheus 监控
* 日志集中化（ELK）

---

# 总结

当前部署：

```
NameServer(2) + Broker(1主1从) + Dashboard
+ hostPath 持久化
```

适用于：

* 私有云
* 中小规模消息系统
* 开发 / 测试 / 轻量生产

---

如果需要可以继续给你：

✔ RocketMQ 多 Master 多副本架构
✔ DLedger（无主架构）
✔ Kubernetes 自动扩缩容方案
✔ Prometheus + Grafana 监控模板
