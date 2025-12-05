kubectl apply -f postgres-deployment.yaml
kubectl apply -f postgres-service.yaml

kubectl apply -f 01-pv.yaml
kubectl apply -f 02-pvc.yaml
kubectl apply -f 03-configmap.yaml
kubectl apply -f 04-secret.yaml
kubectl apply -f 05-deployment.yaml
kubectl apply -f 06-service.yaml

kubectl apply -f ./k8s/mysql/

# 1. 删除现有资源
kubectl delete deployment postgres
kubectl delete pvc postgres-pvc
kubectl delete pv postgres-pv
