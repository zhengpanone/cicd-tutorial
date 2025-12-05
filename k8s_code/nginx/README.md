# 部署步骤
```bash
# 1. 部署所有资源
kubectl apply -f nginx-k8s-complete.yaml

# 2. 查看部署状态
kubectl get all -l app=nginx

# 3. 查看 PV/PVC
kubectl get pv,pvc | grep nginx

# 4. 等待所有 Pod 就绪
kubectl wait --for=condition=ready pod -l app=nginx --timeout=60s

# 5. 查看日志
kubectl logs -l app=nginx -f
```

# 访问测试

## 获取访问地址

```bash
# 获取节点 IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# 显示访问地址
echo "访问地址: http://${NODE_IP}:30080"
echo "健康检查: http://${NODE_IP}:30080/health"
```

**浏览器访问:**
```
http://<NODE_IP>:30080
```

## 命令行测试
```bash
# 测试主页
curl http://<NODE_IP>:30080

# 测试健康检查
curl http://<NODE_IP>:30080/health

# 集群内访问
kubectl run curl --image=curlimages/curl:latest --rm -it -- curl nginx-service/health
```

# 自定义网页内容
## 方法1: 直接编辑宿主机文件
```bash
# 在宿主机上编辑
vim /mnt/host/d/dockerstore/nginx/html/index.html

# 或者创建新文件
echo "<h1>Hello from Nginx</h1>" > /mnt/host/d/dockerstore/nginx/html/test.html

# 访问: http://<NODE_IP>:30080/test.html
```
## 方法2: 通过 Pod 复制文件
```bash
# 从本地复制到 Pod
kubectl cp ./my-website.html <nginx-pod-name>:/usr/share/nginx/html/

# 从 Pod 复制到本地
kubectl cp <nginx-pod-name>:/usr/share/nginx/html/index.html ./backup.html
```
## 方法3: 使用 kubectl exec
```bash
# 进入容器
kubectl exec -it <nginx-pod-name> -- sh

# 编辑文件
cd /usr/share/nginx/html
vi index.html
```

# Nginx 配置管理

## 查看当前配置:
```bash
# 查看主配置
kubectl exec -it <nginx-pod-name> -- cat /etc/nginx/nginx.conf

# 查看虚拟主机配置
kubectl exec -it <nginx-pod-name> -- cat /etc/nginx/conf.d/default.conf

# 测试配置语法
kubectl exec -it <nginx-pod-name> -- nginx -t
```

## 重新加载配置:
```bash
# 修改 ConfigMap 后
kubectl apply -f nginx-k8s.yaml

# 重启 Deployment
kubectl rollout restart deployment nginx

# 或者热重载（推荐）
kubectl exec -it <nginx-pod-name> -- nginx -s reload
```

# 日志查看
```bash
# 查看容器日志
kubectl logs -l app=nginx --tail=100 -f

# 查看访问日志（持久化存储）
kubectl exec -it <nginx-pod-name> -- tail -f /var/log/nginx/access.log

# 查看错误日志
kubectl exec -it <nginx-pod-name> -- tail -f /var/log/nginx/error.log

# 在宿主机查看日志
tail -f /mnt/host/d/dockerstore/nginx/logs/access.log
```

# 常用场景
## 1. 添加反向代理配置
编辑 ConfigMap 的 default.conf:
```nginx
location /api/ {
    proxy_pass http://backend-service:8080/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

## 2. 添加 HTTPS 支持
需要创建 TLS Secret 和修改配置 TODO

## 3. 部署 SPA 应用（Vue/React）
```bash
# 构建前端项目
npm run build

# 复制到 Nginx
kubectl cp ./dist/. <nginx-pod-name>:/usr/share/nginx/html/
```

## 4. 查看 Nginx 状态
```bash
# 访问状态页面（需要在集群内或配置允许的 IP）
kubectl exec -it <nginx-pod-name> -- curl http://localhost/nginx_status
```

# 扩展和优化

## 水平扩展:
```bash
# 扩展到 5 个副本
kubectl scale deployment nginx --replicas=5

# 查看扩展状态
kubectl get pods -l app=nginx -w
```

## 自动扩缩容 (HPA):
```bash
# 创建 HPA
kubectl autoscale deployment nginx --cpu-percent=50 --min=2 --max=10
```

## 查看资源使用:
```bash
kubectl top pods -l app=nginx
```

# 故障排查

```bash
# 查看 Pod 详情
kubectl describe pod -l app=nginx

# 查看事件
kubectl get events --sort-by='.lastTimestamp' | grep nginx

# 进入容器调试
kubectl exec -it <nginx-pod-name> -- sh

# 测试配置
kubectl exec -it <nginx-pod-name> -- nginx -t

# 查看 Nginx 版本
kubectl exec -it <nginx-pod-name> -- nginx -v
```
