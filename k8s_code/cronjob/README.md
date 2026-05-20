# MongoDB
## 部署CronJob

```bash
# 1. 创建 ConfigMap
microk8s kubectl apply -f mongodb-backup-cronjob.yaml

# 2. 立即测试一次（不等到凌晨2点）
microk8s kubectl create job --from=cronjob/mongodb-backup test-backup-now

# 3. 查看测试结果
microk8s kubectl get pods | grep test-backup
microk8s kubectl logs -f <pod-name>

# 4. 查看备份文件
ls -la /opt/dockerstore/mongodb-backup/
```

## 管理CronJob

```bash
# 查看 CronJob 状态
microk8s kubectl get cronjob mongodb-backup

# 查看历史备份任务
microk8s kubectl get jobs -l job-name=mongodb-backup

# 查看备份目录
tree /opt/dockerstore/mongodb-backup/

# 手动触发一次备份
microk8s kubectl create job --from=cronjob/mongodb-backup manual-backup-$(date +%Y%m%d%H%M%S)

# 暂停 CronJob（不删除）
microk8s kubectl patch cronjob mongodb-backup -p '{"spec" : {"suspend" : true }}'

# 恢复 CronJob
microk8s kubectl patch cronjob mongodb-backup -p '{"spec" : {"suspend" : false }}'

# 删除 CronJob（保留备份文件）
microk8s kubectl delete cronjob mongodb-backup
```