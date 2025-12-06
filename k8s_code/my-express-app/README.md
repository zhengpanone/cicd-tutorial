microk8s enable registry
microk8s status

docker build -t my-express-app:latest ./my-express-app

docker tag my-express-app:latest localhost:32000/my-express-app:latest
docker push localhost:32000/my-express-app:latest

microk8s kubectl apply -f my-express-app-k8s.yaml
microk8s kubectl get pods -w


sudo sh -c "echo '127.0.0.1 express.local' >> /etc/hosts"


http://express.local/


# 安装microk8s

```shell
sudo snap install microk8s --classic --channel=1.33/stable
sudo usermod -a -G microk8s $USER
mkdir -p ~/.kube
chmod 0700 ~/.kube

# 
microk8s kubectl get nodes
```