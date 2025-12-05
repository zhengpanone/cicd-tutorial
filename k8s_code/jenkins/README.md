# Jenkins on Kubernetes

Jenkins 是一个开源的持续集成和持续交付工具，用于自动化构建、测试和部署软件。

# 部署步骤

```bash
# 1. 部署 Jenkins
kubectl apply -f jenkins-k8s.yaml

# 2. 查看部署状态
kubectl get all -l app=jenkins

# 3. 查看 PV/PVC
kubectl get pv,pvc | grep jenkins

# 4. 查看 Pod 日志（Jenkins 启动需要几分钟）
kubectl logs -l app=jenkins -f

# 5. 等待 Pod 就绪（可能需要 3-5 分钟）
kubectl wait --for=condition=ready pod -l app=jenkins --timeout=300s
```

# 访问 Jenkins

```bash
# 获取访问地址
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Jenkins 访问地址: http://${NODE_IP}:30090/jenkins"
echo "管理员账号: admin"
echo "管理员密码: jenkins123456"
```

**浏览器访问：**
```
URL: http://<NODE_IP>:30090/jenkins
用户名: admin
密码: jenkins123456
```

# 监控启动进度

```bash
# 实时查看日志
kubectl logs -l app=jenkins -f

# 查看 Pod 状态
watch kubectl get pods -l app=jenkins

# 查看详细信息
kubectl describe pod -l app=jenkins
```

**Jenkins 启动阶段提示：**
```
1. 容器创建中...
2. Jenkins 服务初始化...（1-2分钟）
3. 插件系统初始化...（1-2分钟）
4. 服务启动完成 ✓
```

# 配置 Jenkins Agent

## 配置 JNLP Agent
```bash
# 获取 Jenkins 服务地址
JENKINS_URL=$(kubectl get service jenkins-service -o jsonpath='{.spec.clusterIP}')
echo "Jenkins 内部地址: http://${JENKINS_URL}:8080/jenkins"

# 在 Jenkins 中配置 Agent
# 1. 访问 Jenkins -> 系统管理 -> 节点管理
# 2. 新建节点 -> 选择 "Permanent Agent"
# 3. 配置 Agent 参数
# 4. 使用 JNLP 连接（端口 50000）
```

## 使用 Kubernetes Plugin（推荐）
```bash
# 安装 Kubernetes Plugin
# 1. 访问 Jenkins -> 系统管理 -> 插件管理
# 2. 搜索 "Kubernetes" 并安装
# 3. 配置 Kubernetes Cloud
# 4. 设置 Jenkins URL: http://jenkins-service:8080/jenkins
```

# Jenkins 配置管理

## 查看当前配置
```bash
# 进入 Jenkins 容器
POD_NAME=$(kubectl get pod -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -- bash

# 查看 Jenkins 主目录
ls -la /var/jenkins_home/

# 查看配置文件
cat /var/jenkins_home/config.xml

# 查看插件目录
ls -la /var/jenkins_home/plugins/
```

## 修改配置
```bash
# 编辑 ConfigMap
kubectl edit configmap jenkins-config

# 修改后重启 Deployment
kubectl rollout restart deployment jenkins
```

# 备份和恢复

## 备份 Jenkins 数据
```bash
# 进入容器执行备份
POD_NAME=$(kubectl get pod -l app=jenkins -o jsonpath='{.items[0].metadata.name}')

# 备份整个 Jenkins 目录
kubectl exec -it $POD_NAME -- tar -czf /tmp/jenkins-backup.tar.gz -C /var/jenkins_home .

# 复制备份到本地
kubectl cp $POD_NAME:/tmp/jenkins-backup.tar.gz ./jenkins-backup-$(date +%Y%m%d).tar.gz

# 查看备份文件
ls -lh jenkins-backup-*.tar.gz
```

## 恢复 Jenkins 数据
```bash
# 停止 Jenkins
kubectl scale deployment jenkins --replicas=0

# 复制备份文件到容器
kubectl cp ./jenkins-backup-20241109.tar.gz $POD_NAME:/tmp/restore.tar.gz

# 解压备份
kubectl exec -it $POD_NAME -- tar -xzf /tmp/restore.tar.gz -C /var/jenkins_home/

# 重启 Jenkins
kubectl scale deployment jenkins --replicas=1
```

# 日志查看

```bash
# 查看容器日志
kubectl logs -l app=jenkins --tail=100 -f

# 查看 Jenkins 系统日志
kubectl exec -it $POD_NAME -- tail -f /var/jenkins_home/logs/jenkins.log

# 查看构建日志
kubectl exec -it $POD_NAME -- tail -f /var/jenkins_home/jobs/*/builds/*/log

# 在宿主机查看日志
tail -f /mnt/host/d/dockerstore/jenkins/logs/jenkins.log
```

# 常用场景

## 1. 创建第一个 Pipeline
```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
                sh 'mvn clean compile'
            }
        }
        stage('Test') {
            steps {
                echo 'Testing...'
                sh 'mvn test'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying...'
                sh 'kubectl apply -f deployment.yaml'
            }
        }
    }
}
```

## 2. 配置 Git 集成
```bash
# 在 Jenkins 中配置 Git 凭据
# 1. 访问 Jenkins -> 凭据 -> 系统 -> 全局凭据
# 2. 添加 Git 用户名密码或 SSH 密钥
```

## 3. 配置 Docker 集成
```bash
# 在 Pod 中挂载 Docker socket
# 修改 Deployment 添加 volume:
volumes:
- name: docker-sock
  hostPath:
    path: /var/run/docker.sock
    type: Socket
```

## 4. 配置 Kubernetes 集成
```bash
# 在 Jenkins 中配置 Kubernetes 凭据
# 1. 安装 Kubernetes Credentials Plugin
# 2. 添加 kubeconfig 文件作为凭据
```

# 扩展和优化

## 水平扩展
```bash
# Jenkins 通常不需要水平扩展，但可以增加资源
# 修改 Deployment 中的资源限制
kubectl edit deployment jenkins

# 增加内存和 CPU
resources:
  requests:
    memory: "4Gi"
    cpu: "2000m"
  limits:
    memory: "8Gi"
    cpu: "4000m"
```

## 查看资源使用
```bash
kubectl top pods -l app=jenkins

# 查看详细资源使用
kubectl describe pod -l app=jenkins | grep -A 5 Resources
```

# 故障排查

```bash
# 查看 Pod 详情
kubectl describe pod -l app=jenkins

# 查看事件
kubectl get events --sort-by='.lastTimestamp' | grep jenkins

# 进入容器调试
kubectl exec -it $POD_NAME -- bash

# 检查 Jenkins 服务状态
curl http://localhost:8080/jenkins/login

# 查看系统信息
kubectl exec -it $POD_NAME -- java -jar /usr/share/jenkins/jenkins.war --version

# 检查磁盘空间
kubectl exec -it $POD_NAME -- df -h /var/jenkins_home
```

## 常见问题解决

### 1. Jenkins 启动缓慢
```bash
# 检查资源是否充足
kubectl top pods -l app=jenkins

# 增加 Java 堆内存
# 在 ConfigMap 中修改 JENKINS_JAVA_OPTS:
-Xmx4g -Xms2g
```

### 2. 插件安装失败
```bash
# 检查网络连接
kubectl exec -it $POD_NAME -- curl -I https://updates.jenkins.io

# 手动安装插件
kubectl exec -it $POD_NAME -- wget -P /var/jenkins_home/plugins/ https://updates.jenkins.io/download/plugins/workflow-aggregator/latest/workflow-aggregator.hpi
```

### 3. 构建失败
```bash
# 查看构建日志
kubectl exec -it $POD_NAME -- cat /var/jenkins_home/jobs/<job-name>/builds/<build-number>/log

# 检查构建环境
kubectl exec -it $POD_NAME -- env | grep -i java
```

### 4. 内存不足
```bash
# 查看内存使用
kubectl top pods -l app=jenkins

# 增加内存限制
kubectl edit deployment jenkins
# 修改 resources.limits.memory
```

# 安全配置

## 修改默认密码
```bash
# 编辑 Secret
kubectl edit secret jenkins-secret

# 修改密码后重启
kubectl rollout restart deployment jenkins
```

## 配置 HTTPS
```bash
# 创建 TLS Secret
kubectl create secret tls jenkins-tls --cert=server.crt --key=server.key

# 修改 Service 配置添加 HTTPS 端口
```

# 清理资源

```bash
# 删除所有 Jenkins 资源
kubectl delete -f jenkins-k8s.yaml

# 清理持久化数据（谨慎操作）
sudo rm -rf /mnt/host/d/dockerstore/jenkins/
```