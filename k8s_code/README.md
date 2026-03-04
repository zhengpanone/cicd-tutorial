# 刷新根CA和服务器证书
```bash
# 1. 首先停止 MicroK8s
sudo microk8s stop

# 2. 刷新根CA和所有衍生证书（这是关键步骤）
sudo microk8s refresh-certs --cert ca.crt

# 3. 重新启动 MicroK8s
sudo microk8s start

# 4. 等待完全启动（约30-60秒）
sleep 60
```

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

# 修复ubuntu蓝牙驱动

```shell
# 1. 查看硬件
sudo lsusb | grep -i bluetooth
sudo lspci -nnk | grep -i bluetooth -A3
# 如果 都没有蓝牙控制器 → 属于 硬件总线未加载（PCIe/USB）

# 2. 检查内核消息是否识别蓝牙设备失败
sudo dmesg | grep -i -e bt -e blue -e firmware

# 3. 检查蓝牙驱动是否还在内核中加载
# 查看蓝牙核心模块
sudo lsmod | grep -i bt



# 重新加载蓝牙模块（无重启）
sudo modprobe -r btusb
sudo modprobe btusb

```

## 使用宿主机的网络接口 IP（最可靠）
查找宿主机在 Pod 网络中可见的 IP：
```bash
# 方法 1: 查看默认网关
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# 在 Pod 内执行
ip route | grep default
# 会显示类似: default via 172.17.0.1 dev eth0
# 这个 172.17.0.1 就是宿主机 IP
```
```bash
# 方法 2: 从现有 Pod 查看
kubectl exec -it prometheus-599fd854f5-7q8fx -- sh
# 在 Pod 内
ip route | grep default
# 或
cat /etc/resolv.conf


microk8s kubectl exec -it deployment/prometheus -- sh
```