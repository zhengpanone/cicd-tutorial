# 部署步骤
```bash
# 1. 创建存储目录
sudo mkdir -p /mnt/host/d/dockerstore/gitlab/{config,logs,data}
sudo chmod -R 777 /mnt/host/d/dockerstore/gitlab

# 2. 部署 GitLab
kubectl apply -f gitlab-k8s.yaml

# 3. 查看部署状态
kubectl get all -l app=gitlab

# 4. 查看 PV/PVC
kubectl get pv,pvc | grep gitlab

# 5. 查看 Pod 日志（GitLab 启动需要几分钟）
kubectl logs -l app=gitlab -f

# 6. 等待 Pod 就绪（可能需要 5-10 分钟）
kubectl wait --for=condition=ready pod -l app=gitlab --timeout=600s
```

# 重新加载配置:
```bash
# 修改 ConfigMap 后
kubectl apply -f nginx-k8s.yaml

# 重启 Deployment
kubectl rollout restart deployment nginx

# 或者热重载（推荐）
kubectl exec -it <nginx-pod-name> -- nginx -s reload
```

# 监控启动进度
```bash
# 实时查看日志
kubectl logs -l app=gitlab -f

# 查看 Pod 状态
watch kubectl get pods -l app=gitlab

# 查看详细信息
kubectl describe pod -l app=gitlab
```

**GitLab 启动阶段提示：**
```
1. 容器创建中...
2. GitLab 服务初始化...（1-2分钟）
3. 数据库迁移...（2-3分钟）
4. 服务启动完成 ✓
```
# 访问 GitLab

```bash
# 获取访问地址
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "GitLab 访问地址: http://${NODE_IP}:30088"
echo "管理员账号: root"
echo "管理员密码: gitlab123456"
```

**浏览器访问：**
```
URL: http://<NODE_IP>:30088
用户名: root
密码: gitlab123456
```


# SSH 克隆配置
## 配置 SSH
```bash
# 1. 生成 SSH 密钥（如果还没有）
ssh-keygen -t rsa -b 4096 -C "your.email@example.com"

# 2. 查看公钥
cat ~/.ssh/id_rsa.pub

# 3. 在 GitLab 中添加 SSH 密钥
# 访问: Settings -> SSH Keys -> 粘贴公钥

# 4. 使用 SSH 克隆（注意端口是 30222）
git clone ssh://git@<NODE_IP>:30222/root/my-project.git
```
## 配置 SSH config（可选）
```bash
cat >> ~/.ssh/config << EOF
Host gitlab-k8s
    HostName <NODE_IP>
    Port 30222
    User git
    IdentityFile ~/.ssh/id_rsa
EOF

# 使用别名克隆
git clone ssh://gitlab-k8s/root/my-project.git
```

管理和维护
查看 GitLab 状态：
```bash
POD_NAME=$(kubectl get pod -l app=gitlab -o jsonpath='{.items[0].metadata.name}')

# 进入容器
kubectl exec -it $POD_NAME -- bash

# 查看 GitLab 状态
gitlab-ctl status

# 查看服务日志
gitlab-ctl tail

# 重启服务
gitlab-ctl restart

```
## 备份 GitLab
```bash
# 进入容器执行备份
kubectl exec -it $POD_NAME -- gitlab-backup create

# 备份文件位置
kubectl exec -it $POD_NAME -- ls -lh /var/opt/gitlab/backups/

# 复制备份到本地
kubectl cp $POD_NAME:/var/opt/gitlab/backups/xxx_gitlab_backup.tar ./
```

恢复备份：
```bash
# 复制备份文件到容器
kubectl cp ./xxx_gitlab_backup.tar $POD_NAME:/var/opt/gitlab/backups/

# 停止服务
kubectl exec -it $POD_NAME -- gitlab-ctl stop puma
kubectl exec -it $POD_NAME -- gitlab-ctl stop sidekiq

# 恢复
kubectl exec -it $POD_NAME -- gitlab-backup restore BACKUP=xxx

# 重启 GitLab
kubectl exec -it $POD_NAME -- gitlab-ctl restart
```

# 配置调整
## 修改外部 URL：

```bash
# 编辑 ConfigMap
kubectl edit configmap gitlab-config

# 修改 external_url
external_url 'http://<YOUR_DOMAIN_OR_IP>:30088'

# 重启 Pod
kubectl rollout restart deployment gitlab
```

调整资源限制：
```yaml
# 如果内存不足，可以降低资源限制
resources:
  requests:
    memory: "2Gi"    # 最小 2GB
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```




