# 部署步骤
```bash

```

# 连接测试

## 集群内访问

```bash

```

## 集群外访问
```bash

```


# 常用操作
```bash

```


# 配置调整
## 如果不需要外部访问: 删除 NodePort Service

```bash

```

# 监控检查

```bash

```

# 删除资源

```bash
microk8s kubectl delete pods -l app=rabbitmq
microk8s kubectl delete pod -l app=rabbitmq --force --grace-period=0
microk8s kubectl delete statefulset rabbitmq
microk8s kubectl delete pvc -l app=elasticsearch
microk8s kubectl delete statefulset elasticsearch
kubectl delete job es-init-permissions
```

# 启动资源
```bash
kubectl rollout restart deployment/mongodb
# 取第一个 mongodb Pod 名
POD=$(microk8s kubectl get pod -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD -- mongosh --eval 'db.getSiblingDB('admin').getUsers()'
kubectl exec -it $POD -- mongosh --eval 'db.getSiblingDB("admin").createUser({user:"admin", pwd:"mongodb123456", roles:[{role:"root", db:"admin"}]})'
kubectl exec -it deployment/mongodb -- mongosh
kubectl exec -it $POD -- mongosh \
-u admin -p mongodb123456 --authenticationDatabase admin
```
