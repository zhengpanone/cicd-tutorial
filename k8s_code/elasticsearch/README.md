部署步骤
bash# 1. 应用所有资源
kubectl apply -f elasticsearch-k8s.yaml

# 2. 查看初始化 Job
kubectl get jobs
kubectl logs -f job/es-init-permissions

# 3. 查看 StatefulSet 和 Pod 状态（启动需要 3-5 分钟）
kubectl get statefulset
kubectl get pods -l app=elasticsearch -w

# 4. 查看服务
kubectl get svc

# 5. 检查集群健康状态
kubectl exec -it elasticsearch-0 -- curl -X GET "localhost:9200/_cluster/health?pretty"

# 6. 查看集群节点
kubectl exec -it elasticsearch-0 -- curl -X GET "localhost:9200/_cat/nodes?v"
🌐 访问方式

NodePort: http://<节点IP>:30920
Ingress: http://es.example.com
集群内: http://elasticsearch-service:9200

测试连接
bash# 从集群外访问
curl http://<节点IP>:30920

# 查看集群信息
curl http://<节点IP>:30920/_cluster/health?pretty

# 查看所有索引
curl http://<节点IP>:30920/_cat/indices?v
⚙️ 重要配置说明

集群节点: 3个节点（elasticsearch-0, elasticsearch-1, elasticsearch-2）
内存配置: 每个节点 2GB（JVM heap 1GB）
存储配置: 每个节点 30GB 数据盘
端口:

9200: HTTP API
9300: 节点间通信
30920: NodePort 外部访问


安全: 开发环境配置，生产环境需启用 xpack.security
密码: elastic123（请在生产环境修改）

📊 扩展配置
调整 JVM 内存
修改 ConfigMap 中的：
yaml-Xms2g  # 初始堆内存
-Xmx2g  # 最大堆内存
调整副本数
bashkubectl scale statefulset elasticsearch --replicas=5
查看日志
bashkubectl logs -f elasticsearch-0
kubectl logs -f elasticsearch-1
kubectl logs -f elasticsearch-2