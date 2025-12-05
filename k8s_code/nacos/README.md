# Nacos Kubernetes 部署指南

## 概述

本配置用于在Kubernetes集群中部署Nacos服务注册与配置中心，使用MySQL作为后端数据库。

## 部署步骤

### 1. 前置条件
- Kubernetes集群（v1.19+）
- kubectl命令行工具
- MySQL数据库服务（已部署或通过k8s部署）

### 2. 部署Nacos
```bash
# 应用所有配置
kubectl apply -f nacos-k8s.yaml

# 查看部署状态
kubectl get pods -l app=nacos
kubectl get services -l app=nacos

# 查看详细状态
kubectl describe pod -l app=nacos

# 重启 Deployment
kubectl rollout restart deployment nacos

# 删除现有的 Deployment
kubectl delete deployment nacos


# 1. 查看 Pod 的详细状态
kubectl describe pod nacos-66c9996687-phchv

# 2. 查看所有容器的状态（包括 init 容器）
kubectl get pod nacos-66c9996687-phchv -o jsonpath='{.status.initContainerStatuses[*].name}' && echo
kubectl get pod nacos-66c9996687-phchv -o jsonpath='{.status.initContainerStatuses[*].state}' && echo

# 3. 查看每个 initContainer 的日志
kubectl logs nacos-65bc996df9-cj5mm -c wait-for-mysql
kubectl logs nacos-65bc996df9-cj5mm -c init-nacos-db
kubectl logs nacos-65bc996df9-cj5mm -c execute-db-script

# 4. 查看 Pod 的 Events
kubectl get events --sort-by='.lastTimestamp' | grep nacos
```

### 3. 验证部署
```bash
# 检查Pod状态
kubectl get pods -l app=nacos -w

# 查看日志
kubectl logs -f deployment/nacos

# 检查服务
kubectl get svc nacos-service nacos-service-nodeport
```

## 连接测试

### 集群内访问
```bash
# 通过ClusterIP服务访问
kubectl exec -it <nacos-pod> -- curl http://nacos-service:8848/nacos/actuator/health

# 获取Nacos Pod IP
kubectl get pod -l app=nacos -o wide

# 直接访问Pod
curl http://<nacos-pod-ip>:8848/nacos
```

### 集群外访问
```bash
# 通过NodePort访问（端口30848）
# 浏览器访问：http://<node-ip>:30848/nacos
# 默认用户名/密码：nacos/nacos

# 获取节点IP
kubectl get nodes -o wide

# 测试连接
curl http://<node-ip>:30848/nacos/actuator/health
```

## 常用操作

### 查看配置
```bash
# 查看ConfigMap
kubectl get configmap nacos-config -o yaml

# 查看Secret（敏感信息会base64编码）
kubectl get secret nacos-secret -o yaml

# 查看PVC状态
kubectl get pvc -l app=nacos
```

### 重启服务
```bash
# 重启Deployment
kubectl rollout restart deployment/nacos

# 查看重启状态
kubectl rollout status deployment/nacos
```

### 备份与恢复
```bash
# 备份数据（PV中的数据）
# 数据存储在：/mnt/host/d/dockerstore/nacos/data
# 日志存储在：/mnt/host/d/dockerstore/nacos/logs

# 导出配置
kubectl get configmap nacos-config -o yaml > nacos-config-backup.yaml
kubectl get secret nacos-secret -o yaml > nacos-secret-backup.yaml
```

## 配置调整

### 修改数据库连接
```bash
# 更新Secret中的数据库配置
kubectl edit secret nacos-secret

# 修改以下字段：
# MYSQL_HOST: mysql-service
# MYSQL_PORT: "3306"
# MYSQL_ROOT_PASSWORD: root
```

### 调整资源限制
```bash
# 编辑Deployment资源限制
kubectl edit deployment nacos

# 修改resources部分
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### 如果不需要外部访问：删除NodePort Service
```bash
kubectl delete service nacos-service-nodeport
```

## 监控检查

### 健康检查
```bash
# 检查Pod健康状态
kubectl get pods -l app=nacos

# 查看事件
kubectl get events --field-selector involvedObject.name=nacos

# 检查资源使用
kubectl top pod -l app=nacos
```

### 日志分析
```bash
# 查看实时日志
kubectl logs -f deployment/nacos

# 查看特定时间段的日志
kubectl logs deployment/nacos --since=1h

# 查看初始化容器日志
kubectl logs deployment/nacos -c init-nacos-db
kubectl logs deployment/nacos -c wait-for-mysql
```

### 故障排查
```bash
# 进入Pod调试
kubectl exec -it <nacos-pod> -- /bin/bash

# 检查网络连通性
kubectl exec -it <nacos-pod> -- ping mysql-service

# 检查数据库连接
kubectl exec -it <nacos-pod> -- mysql -hmysql-service -uroot -proot -e "SHOW DATABASES;"
```

## 架构说明

### 组件关系
- **Nacos Pod**：主服务容器
- **MySQL Service**：数据库服务依赖
- **PV/PVC**：数据持久化存储
- **ConfigMap**：应用配置
- **Secret**：敏感信息存储

### 依赖管理
- 使用initContainer实现类似docker-compose的depends_on功能
- wait-for-mysql容器确保MySQL服务就绪后再启动Nacos
- init-nacos-db容器负责数据库初始化和表结构创建

## 注意事项

1. **数据库依赖**：确保MySQL服务在Nacos之前部署完成
2. **存储配置**：根据实际环境调整PV的hostPath路径
3. **网络策略**：确保Pod间网络通信正常
4. **资源分配**：根据实际负载调整资源限制
5. **安全配置**：生产环境建议启用Nacos认证
