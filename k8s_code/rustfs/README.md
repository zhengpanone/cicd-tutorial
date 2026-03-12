# RustFS on Kubernetes

RustFS 是一个 **高性能 S3 兼容对象存储系统**，用于存储文件、备份数据和构建私有云存储服务。

RustFS 提供：

* S3 API 接口
* Web Console 管理界面
* 高性能对象存储
* Kubernetes 原生部署

---

# 部署步骤

```bash
# 1. 部署 RustFS
kubectl apply -f rustfs-k8s.yaml

# 2. 查看部署状态
kubectl get all -l app=rustfs

# 3. 查看 PV/PVC
kubectl get pv,pvc | grep rustfs

# 4. 查看 Pod 日志
kubectl logs -l app=rustfs -f

# 5. 等待 Pod 就绪
kubectl wait --for=condition=ready pod -l app=rustfs --timeout=300s
```

---

# 访问 RustFS

```bash
# 获取节点 IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "RustFS API 地址: http://${NODE_IP}:30900"
echo "RustFS Console 地址: http://${NODE_IP}:30901"

echo "AccessKey: rustfsadmin"
echo "SecretKey: rustfsadmin"
```

---

## 浏览器访问

### Web Console

```
http://<NODE_IP>:30901
```

登录：

```
AccessKey: rustfsadmin
SecretKey: rustfsadmin
```

---

### S3 API

```
http://<NODE_IP>:30900
```

可用于：

* AWS CLI
* MinIO Client
* Java SDK
* Python SDK

---

# 监控启动进度

```bash
# 实时查看日志
kubectl logs -l app=rustfs -f

# 查看 Pod 状态
watch kubectl get pods -l app=rustfs

# 查看详细信息
kubectl describe pod -l app=rustfs
```

---

## RustFS 启动阶段

```
1. 容器启动
2. 数据目录初始化
3. RustFS 服务启动
4. Web Console 启动
5. 服务就绪 ✓
```

---

# RustFS 配置管理

## 进入容器

```bash
POD_NAME=$(kubectl get pod -l app=rustfs -o jsonpath='{.items[0].metadata.name}')

kubectl exec -it $POD_NAME -- sh
```

---

## 查看数据目录

```bash
ls -la /data
```

RustFS 默认目录：

```
/data
└── rustfs0
```

---

## 查看日志

```bash
ls -la /logs
```

---

# 使用 S3 客户端

## 安装 MinIO Client

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/
```

---

## 配置 RustFS

```bash
mc alias set rustfs http://NODE_IP:30900 rustfsadmin rustfsadmin
```

---

## 创建 Bucket

```bash
mc mb rustfs/test-bucket
```

---

## 上传文件

```bash
mc cp test.txt rustfs/test-bucket/
```

---

## 查看文件

```bash
mc ls rustfs/test-bucket
```

---

# 备份和恢复

## 备份数据

RustFS 数据存储在：

```
/opt/dockerstore/rustfs/data
```

备份：

```bash
tar -czf rustfs-backup-$(date +%Y%m%d).tar.gz /opt/dockerstore/rustfs/data
```

---

## 恢复数据

```bash
tar -xzf rustfs-backup-20241109.tar.gz -C /opt/dockerstore/rustfs/
```

然后重启：

```bash
kubectl rollout restart deployment rustfs
```

---

# 日志查看

```bash
# 查看容器日志
kubectl logs -l app=rustfs --tail=100 -f
```

---

# 常用操作

## 创建 Bucket

```bash
mc mb rustfs/mybucket
```

---

## 删除 Bucket

```bash
mc rb rustfs/mybucket
```

---

## 上传目录

```bash
mc cp -r ./data rustfs/mybucket
```

---

# 扩展和优化

## 增加资源

```bash
kubectl edit deployment rustfs
```

增加资源：

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

---

## 查看资源使用

```bash
kubectl top pods -l app=rustfs
```

---

# 故障排查

## 查看 Pod

```bash
kubectl describe pod -l app=rustfs
```

---

## 查看事件

```bash
kubectl get events --sort-by='.lastTimestamp' | grep rustfs
```

---

## 进入容器

```bash
kubectl exec -it $POD_NAME -- sh
```

---

## 检查服务端口

```bash
ss -lntp
```

应该看到：

```
0.0.0.0:9000
0.0.0.0:9001
```

---

# 常见问题

## 1 Pod 启动失败

```bash
kubectl logs -l app=rustfs
```

常见原因：

* PV 未挂载
* 数据目录不存在
* 权限问题

---

## 2 Volume not found

确保：

```bash
kubectl get pvc
```

状态必须是：

```
STATUS: Bound
```

---

## 3 Web Console 无法访问

确认 Service：

```bash
kubectl get svc rustfs
```

应该看到：

```
9000:30900/TCP
9001:30901/TCP
```

---

# 清理资源

```bash
kubectl delete -f rustfs-k8s.yaml
```

清理数据：

```bash
sudo rm -rf /opt/dockerstore/rustfs
```

⚠️ **删除后数据不可恢复**

---

如果你需要，我可以再给你一份 **完整版 RustFS Kubernetes 文档（生产级）**，包括：

* **Ingress 访问**
* **TLS HTTPS**
* **多节点分布式 RustFS**
* **Gateway API**
* **自动扩容**
* **对象存储监控（Prometheus + Grafana）**

这一套基本就是 **云厂商 S3 的私有化部署架构**。
