# 部署步骤
```shell
# 1. 部署所有资源
kubectl apply -f postgres-k8s.yaml

# 2. 查看部署状态
kubectl get all -l app=postgres

# 3. 查看 PV/PVC
kubectl get pv,pvc | grep postgres

# 4. 查看 Pod 日志
kubectl logs -l app=postgres -f
```

# 连接测试

## 集群内访问

```shell
kubectl run postgres-client --rm -it --image=postgres:16.10-alpine -- sh
```

## 集群外访问
```shell
# 获取节点 IP
kubectl get nodes -o wide

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
