# 部署步骤
```shell
# 1. 部署所有资源
kubectl apply -f redis-k8s.yaml

# 2. 查看部署状态
kubectl get all -l app=redis

# 3. 查看 PV/PVC
kubectl get pv,pvc | grep redis

# 4. 查看 Pod 日志
kubectl logs -l app=redis -f
```

# 连接测试

## 集群内访问

```shell
kubectl run redis-client --rm -it --image=redis:7.2-alpine -- sh
redis-cli -h redis-service -a redis123456 ping
```

## 集群外访问
```shell
# 获取节点 IP
kubectl get nodes -o wide

# 连接 Redis
redis-cli -h <NODE_IP> -p 30379 -a redis123456
```




# 常用操作
```shell
# 进入 Redis 容器
kubectl exec -it <redis-pod-name> -- redis-cli -a redis123456

# 查看 Redis 信息
kubectl exec -it <redis-pod-name> -- redis-cli -a redis123456 INFO

# 测试读写
kubectl exec -it <redis-pod-name> -- redis-cli -a redis123456 SET test "hello"
kubectl exec -it <redis-pod-name> -- redis-cli -a redis123456 GET test
```


# 配置调整
# # 如果不需要外部访问: 删除 NodePort Service


```shell
kubectl delete service redis-service-nodeport
```

# 监控检查

```shell
# 查看 Redis 连接数
kubectl exec -it <redis-pod-name> -- redis-cli -a redis123456 INFO clients

# 查看内存使用
kubectl exec -it <redis-pod-name> -- redis-cli -a redis123456 INFO memory

# 查看持久化状态
kubectl exec -it <redis-pod-name> -- redis-cli -a redis123456 INFO persistence
```
