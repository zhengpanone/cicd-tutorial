# Jenkins on Kubernetes with Kaniko

这个目录提供一个可在 Docker Desktop Kubernetes 中运行的 Jenkins 示例。Jenkins 使用持久化存储保存数据和日志，并预置 Maven、kubectl、Kaniko 容器，方便在 Pipeline 中完成 Java 构建、Kubernetes 部署和镜像构建。

## 资源说明

| 资源 | 说明 |
| --- | --- |
| `Namespace/devops` | Jenkins 所在命名空间 |
| `Deployment/jenkins` | Jenkins 主服务，包含 `jenkins`、`maven`、`kubectl`、`kaniko` 四个容器 |
| `Service/jenkins-service-nodeport` | 暴露 Jenkins Web 和 JNLP 端口 |
| `PV/PVC` | 持久化 Jenkins 数据、日志、Maven 本地仓库 |
| `ConfigMap/jenkins-config` | Jenkins 启动参数和 JVM 参数 |
| `ConfigMap/jenkins-init-groovy` | 初始化管理员账号 |
| `Secret/jenkins-secret` | 默认管理员账号密码 |
| `Secret/kaniko-docker-config` | Kaniko 推送镜像使用的 Docker config，占位配置默认为空 |
| `ServiceAccount/jenkins` + RBAC | Jenkins Kubernetes Plugin 创建构建 Pod 所需权限 |

## 前置条件

当前 YAML 按 Docker Desktop Kubernetes 编写，PV 使用如下 hostPath：

```text
/run/desktop/mnt/host/e/dockerstore/jenkins/data
/run/desktop/mnt/host/e/dockerstore/jenkins/logs
/run/desktop/mnt/host/e/dockerstore/jenkins/maven-repo
```

如果你的宿主机目录不是 `E:\dockerstore\jenkins`，需要先修改 `jenkins-k8s-kaniko.yaml` 中的三个 `hostPath.path`。

确认当前 Kubernetes context：

```bash
kubectl config current-context
```

Docker Desktop 环境通常应显示：

```text
docker-desktop
```

## 部署

在当前目录执行：

```bash
kubectl apply -f jenkins-k8s-kaniko.yaml
```

等待 Jenkins 启动完成：

```bash
kubectl rollout status deployment/jenkins -n devops --timeout=240s
```

查看 Pod 状态：

```bash
kubectl get pods -n devops -l app=jenkins -o wide
```

正常结果中应看到：

```text
READY   STATUS
4/4     Running
```

查看 Service：

```bash
kubectl get svc -n devops jenkins-service-nodeport
```

## 访问 Jenkins

浏览器访问：

```text
http://localhost:30090/jenkins/login
```

默认账号：

```text
用户名：admin
密码：jenkins123456
```

> 注意：这个密码只适合本地教程环境。用于长期环境时，请修改 `jenkins-secret`，并重新启动 Deployment。

验证访问：

```bash
curl -I http://localhost:30090/jenkins/login
```

Windows PowerShell 可以使用：

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:30090/jenkins/login"
```

## 已验证状态

本配置已在 Docker Desktop Kubernetes 中验证通过：

```bash
kubectl apply -f jenkins-k8s-kaniko.yaml
kubectl rollout status deployment/jenkins -n devops --timeout=240s
kubectl logs -n devops -l app=jenkins -c jenkins --tail=80
```

Jenkins 启动成功时，日志中会出现：

```text
Jenkins is fully up and running
```

## 容器说明

Deployment 中包含四个容器：

| 容器 | 镜像 | 用途 |
| --- | --- | --- |
| `jenkins` | `jenkins/jenkins:lts-jdk21` | Jenkins Web 和控制器 |
| `maven` | `maven:3.9.9-eclipse-temurin-21` | Java/Maven 构建环境 |
| `kubectl` | `bitnami/kubectl:latest` | 执行 Kubernetes 部署命令 |
| `kaniko` | `gcr.io/kaniko-project/executor:debug` | 无 Docker daemon 构建并推送镜像 |

查看指定容器日志：

```bash
kubectl logs -n devops -l app=jenkins -c jenkins --tail=100 -f
```

进入 Jenkins 容器：

```bash
POD_NAME=$(kubectl get pod -n devops -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n devops -it $POD_NAME -c jenkins -- bash
```

进入 Maven 容器：

```bash
kubectl exec -n devops -it $POD_NAME -c maven -- bash
```

进入 kubectl 容器：

```bash
kubectl exec -n devops -it $POD_NAME -c kubectl -- sh
```

进入 Kaniko 容器：

```bash
kubectl exec -n devops -it $POD_NAME -c kaniko -- sh
```

## kubectl kubeconfig Secret

`kubectl` 容器需要 kubeconfig 才能访问 Kubernetes API。当前清单会把 `kubeconfig-secret` 挂载到：

```text
/home/jenkins/.kube/config
```

在应用 `jenkins-k8s-kaniko.yaml` 前，先创建 Secret：

```bash
kubectl create secret generic kubeconfig-secret \
  -n devops \
  --from-file=config=$HOME/.kube/config
```

Windows PowerShell 示例：

```powershell
kubectl create secret generic kubeconfig-secret `
  -n devops `
  --from-file=config=$env:USERPROFILE\.kube\config
```

如果 Secret 已存在，需要先删除再重建：

```bash
kubectl delete secret kubeconfig-secret -n devops
kubectl create secret generic kubeconfig-secret \
  -n devops \
  --from-file=config=$HOME/.kube/config
```

Windows PowerShell 示例：

```powershell
kubectl delete secret kubeconfig-secret -n devops
kubectl create secret generic kubeconfig-secret `
  -n devops `
  --from-file=config=$env:USERPROFILE\.kube\config
```

如果使用 Jenkins Kubernetes Plugin 动态创建 Agent Pod，还需要在对应 Pod Template 的 `kubectl` 容器中挂载同一个 `kubeconfig-secret`，并设置：

```text
KUBECONFIG=/home/jenkins/.kube/config
```

## Kaniko 镜像仓库认证

`kaniko-docker-config` 默认内容为空：

```json
{
  "auths": {}
}
```

如果要推送镜像，需要替换为真实 registry 登录信息。推荐用下面方式重新创建 Secret：

```bash
kubectl delete secret kaniko-docker-config -n devops
kubectl create secret generic kaniko-docker-config \
  -n devops \
  --from-file=config.json=$HOME/.docker/config.json
kubectl rollout restart deployment/jenkins -n devops
```

Windows PowerShell 示例：

```powershell
kubectl delete secret kaniko-docker-config -n devops
kubectl create secret generic kaniko-docker-config `
  -n devops `
  --from-file=config.json=$env:USERPROFILE\.docker\config.json
kubectl rollout restart deployment/jenkins -n devops
```

## Pipeline 示例

下面示例演示在当前 Jenkins Pod 的多容器环境中执行 Maven 构建、Kaniko 构建镜像、kubectl 部署。

```groovy
pipeline {
    agent any

    environment {
        IMAGE = 'your-registry.example.com/demo/my-springboot-app:latest'
    }

    stages {
        stage('Build') {
            steps {
                container('maven') {
                    sh 'mvn -version'
                    sh 'mvn clean package -DskipTests'
                }
            }
        }

        stage('Build Image') {
            steps {
                container('kaniko') {
                    sh '''
                    /kaniko/executor \
                      --context=${WORKSPACE} \
                      --dockerfile=${WORKSPACE}/Dockerfile \
                      --destination=${IMAGE}
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                container('kubectl') {
                    sh 'kubectl apply -f k8s/deployment.yaml'
                }
            }
        }
    }
}
```

如果使用 Jenkins Kubernetes Plugin 动态创建 Agent Pod，需要在 Jenkins 中安装并配置 Kubernetes 插件；当前 YAML 已经创建了 `ServiceAccount/jenkins` 和相关 RBAC。

## Jenkins Kubernetes Plugin 配置建议

安装插件：

1. 进入 Jenkins：`系统管理` -> `插件管理`
2. 安装 `Kubernetes` 插件
3. 进入 `系统管理` -> `Clouds` -> `New cloud` -> `Kubernetes`

常用配置：

```text
Kubernetes URL: https://kubernetes.default.svc
Kubernetes Namespace: devops
Jenkins URL: http://jenkins-service-nodeport.devops.svc.cluster.local:8080/jenkins
Jenkins tunnel: jenkins-service-nodeport.devops.svc.cluster.local:50000
Credentials: 使用当前 Pod ServiceAccount，或手动配置 kubeconfig/token
```

## 常用运维命令

查看资源：

```bash
kubectl get all -n devops -l app=jenkins
kubectl get pv | grep jenkins
kubectl get pvc -n devops
```

查看事件：

```bash
kubectl get events -n devops --sort-by='.lastTimestamp'
```

重启 Jenkins：

```bash
kubectl rollout restart deployment/jenkins -n devops
kubectl rollout status deployment/jenkins -n devops --timeout=240s
```

查看配置：

```bash
kubectl get configmap jenkins-config -n devops -o yaml
kubectl get secret jenkins-secret -n devops -o yaml
```

## 备份和恢复

备份 Jenkins home：

```bash
POD_NAME=$(kubectl get pod -n devops -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n devops $POD_NAME -c jenkins -- tar -czf /tmp/jenkins-backup.tar.gz -C /var/jenkins_home .
kubectl cp devops/$POD_NAME:/tmp/jenkins-backup.tar.gz ./jenkins-backup.tar.gz -c jenkins
```

恢复时建议先停掉 Jenkins：

```bash
kubectl scale deployment/jenkins -n devops --replicas=0
```

恢复数据后再启动：

```bash
kubectl scale deployment/jenkins -n devops --replicas=1
kubectl rollout status deployment/jenkins -n devops --timeout=240s
```

## 常见问题

### Pod 是 `CrashLoopBackOff`

先看 Jenkins 容器日志：

```bash
kubectl logs -n devops -l app=jenkins -c jenkins --tail=120
```

如果看到类似：

```text
missing rw permissions on JENKINS_HOME
Permission denied
```

说明 hostPath 目录权限不对。当前 YAML 已经通过 `initContainer/fix-jenkins-volume-permissions` 自动执行：

```bash
chown -R 1000:1000 /var/jenkins_home /var/log/jenkins
```

如果仍失败，检查 Docker Desktop 是否允许访问对应宿主机磁盘。

### `/var/cache/jenkins/war` 权限错误

本配置已经把 Jenkins webroot 改到：

```text
/var/jenkins_home/war
```

不要再改回 `/var/cache/jenkins/war`，否则非 root 用户可能无法写入。

### 登录失败

确认初始化脚本执行过：

```bash
kubectl logs -n devops -l app=jenkins -c jenkins --tail=200 | grep init.groovy
```

如果 Jenkins home 中已经存在旧数据，初始化脚本可能不会覆盖旧账号。可以在 Jenkins UI 中修改密码，或清理持久化数据后重新部署。

### 页面访问不到

检查 Service 和 Pod：

```bash
kubectl get svc -n devops jenkins-service-nodeport
kubectl get pods -n devops -l app=jenkins
```

本地 Docker Desktop 访问地址为：

```text
http://localhost:30090/jenkins/login
```

### Kaniko 推送镜像失败

检查 `/kaniko/.docker/config.json` 是否包含目标仓库认证：

```bash
POD_NAME=$(kubectl get pod -n devops -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n devops -it $POD_NAME -c kaniko -- cat /kaniko/.docker/config.json
```

如果是空的 `auths`，请按“Kaniko 镜像仓库认证”章节重新创建 Secret。

## 清理资源

删除 Jenkins 资源：

```bash
kubectl delete -f jenkins-k8s-kaniko.yaml
```

因为 PV 的回收策略是 `Retain`，删除 YAML 后宿主机数据目录仍会保留。如需彻底清理，请手动删除宿主机目录：

```text
E:\dockerstore\jenkins\data
E:\dockerstore\jenkins\logs
E:\dockerstore\jenkins\maven-repo
```
