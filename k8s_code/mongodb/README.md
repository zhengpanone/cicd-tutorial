# 部署步骤
```shell
# 1. 部署所有资源
kubectl apply -f mongodb-k8s.yaml

# 2. 查看部署状态
kubectl get all -l app=mongodb

# 3. 查看 PV/PVC
kubectl get pv,pvc | grep mongodb

# 4. 查看 Pod 日志
kubectl logs -l app=mongodb -f

# 5. 等待 Pod 就绪
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=120s

# 查看 Pod 状态
kubectl get pods -l app=mongodb

# 测试连接
kubectl exec -it $(kubectl get pod -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- mongosh --eval "db.version()"

```

# 重新部署
```bash
# 1. 删除旧的 ConfigMap
kubectl delete configmap mongodb-config

# 2. 重新应用配置
kubectl apply -f mongodb-k8.yaml

# 3. 重启 Pod（强制重新加载配置）
kubectl rollout restart deployment mongodb

# 4. 查看日志确认启动成功
kubectl logs -l app=mongodb -f
```

# 连接测试

## 集群内访问

```shell
# 运行临时客户端
kubectl run mongodb-client --rm -it --image=mongo:7.0 -- bash

# 在容器内连接
mongosh "mongodb://admin:mongodb123456@mongodb-service:27017/admin"
```

## 集群外访问
```shell
# 获取节点 IP
kubectl get nodes -o wide

# 使用 mongosh 连接
mongosh "mongodb://admin:mongodb123456@<NODE_IP>:30017/admin"

# 或使用连接字符串
mongosh --host <NODE_IP> --port 30017 -u admin -p mongodb123456 --authenticationDatabase admin
```


# 常用操作
## 进入 MongoDB 容器
```shell
# 获取 Pod 名称
kubectl get pods -l app=mongodb

# 进入容器
kubectl exec -it <mongodb-pod-name> -- mongosh -u admin -p mongodb123456 --authenticationDatabase admin
```
## MongoDB Shell 常用命令
```javascript
// 查看数据库列表
show dbs

// 切换/创建数据库
use mydb

// 创建集合并插入数据
db.users.insertOne({name: "张三", age: 25})

// 查询数据
db.users.find()

// 创建新用户
db.createUser({
  user: "appuser",
  pwd: "apppass123",
  roles: [{role: "readWrite", db: "mydb"}]
})

// 查看当前用户
db.runCommand({connectionStatus: 1})

// 查看数据库统计
db.stats()
```

## 创建应用数据库和用户
### 方法1: 使用 kubectl exec
```shell
bashkubectl exec -it <mongodb-pod-name> -- mongosh -u admin -p mongodb123456 --authenticationDatabase admin --eval '
use mydb;
db.createUser({
  user: "myapp",
  pwd: "myapppass",
  roles: [{role: "readWrite", db: "mydb"}]
});
'
```

### 方法2: 通过初始化脚本 (推荐生产环境)
添加 ConfigMap:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-init-script
  namespace: default
data:
  init-mongo.js: |
    db = db.getSiblingDB('mydb');
    db.createUser({
      user: 'myapp',
      pwd: 'myapppass',
      roles: [{role: 'readWrite', db: 'mydb'}]
    });
    db.createCollection('users');
    db.users.insertOne({name: 'test', createdAt: new Date()});
```


# 监控检查
查看 MongoDB 状态
```shell
kubectl exec -it <mongodb-pod-name> -- mongosh -u admin -p mongodb123456 --authenticationDatabase admin --eval "db.serverStatus()"
```

查看慢查询
```
kubectl exec -it <mongodb-pod-name> -- mongosh -u admin -p mongodb123456 --authenticationDatabase admin --eval "db.system.profile.find().limit(10).pretty()"
```

备份数据库
```bash
# 进入容器
kubectl exec -it <mongodb-pod-name> -- bash

# 备份
mongodump --uri="mongodb://admin:mongodb123456@localhost:27017/admin" --out=/tmp/backup

# 从宿主机复制备份
kubectl cp <mongodb-pod-name>:/tmp/backup ./mongodb-backup
```

恢复数据库
```bash
# 复制备份到容器
kubectl cp ./mongodb-backup <mongodb-pod-name>:/tmp/backup

# 进入容器恢复
kubectl exec -it <mongodb-pod-name> -- mongorestore --uri="mongodb://admin:mongodb123456@localhost:27017/admin" /tmp/backup
```

## 配置调整建议
修改管理员密码:
```yaml
# 修改 Secret 部分
stringData:
  MONGO_INITDB_ROOT_USERNAME: admin
  MONGO_INITDB_ROOT_PASSWORD: 你的新密码  # 修改这里
  MONGO_INITDB_DATABASE: mydb
增加内存限制:
yaml# 修改 Deployment 的 resources
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```
配置副本集 (高可用):  **TODO**

🔍 故障排查
```bash
# 查看 Pod 详细信息
kubectl describe pod -l app=mongodb

# 查看 MongoDB 日志
kubectl exec -it <mongodb-pod-name> -- tail -f /var/log/mongodb/mongod.log

# 测试端口连通性
kubectl exec -it <mongodb-pod-name> -- netstat -tlnp | grep 27017

# 查看环境变量
kubectl exec -it <mongodb-pod-name> -- env | grep MONGO
```