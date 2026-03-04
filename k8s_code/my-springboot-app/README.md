```shell
# 构建镜像
docker build -t my-springboot-app:1.0.0 .

# 运行镜像
docker run -d \
  -p 18080:8080 \
  --name my-springboot-app \
  my-springboot-app:1.0.0

# tag镜像
docker tag my-springboot-app:1.0.0 localhost:32000/my-springboot-app:1.0.0

# 推送镜像
docker push localhost:32000/my-springboot-app:1.0.0

# 删除镜像
docker rmi my-springboot-app:1.0.0
docker rmi localhost:32000/my-springboot-app:1.0.0

# 确认集群中存在
kubectl get gatewayclass

kubectl apply -f my-springboot-k8s.yaml

kubectl get pods -n spring-app
kubectl get svc -n spring-app
kubectl get endpoints -n spring-app
kubectl get gateway -n spring-app
kubectl get httproute -n spring-app

# 获取网关信息
kubectl get gateway -n spring-app

# 获取路由信息
kubectl get httproute -n spring-app

# Port-forward
kubectl port-forward -n spring-app svc/my-springboot-app-service 18081:81
```