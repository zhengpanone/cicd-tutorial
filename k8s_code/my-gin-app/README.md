# k8s 部署go项目

## 初始化项目

```sh
mkdir my-gin-app
cd my-gin-app
go mod init my-gin-app
```

## 构建镜像

```sh
docker build --pull --no-cache -t my-gin-app:v1.3 .
docker tag my-gin-app:v1.3 localhost:32000/my-gin-app:v1.3
docker push localhost:32000/my-gin-app:v1.3
```

## 部署

```sh
kubectl create namespace test # 创建命名空间
kubectl apply -f my-gin-app-k8s.yaml
kubectl get svc,deploy,pod -n test
kubectl get pods -w
kubectl -n test port-forward svc/my-gin-app 8081:8080
# curl http://localhost:8081/
```
