# Gitea on Kubernetes

Gitea 鏄竴涓交閲忕骇鑷墭绠?Git 鏈嶅姟锛岄€傚悎鍦ㄦ湰鍦?Kubernetes銆佸疄楠岀幆澧冩垨灏忓洟闃熷唴閮ㄧ幆澧冧腑鏇夸唬杈冮噸鐨?GitLab銆傝繖涓洰褰曟彁渚?Docker Desktop Kubernetes 涓婄殑鍗曡妭鐐归儴缃叉竻鍗曪紝浣跨敤 SQLite 鍜?hostPath 鎸佷箙鍖栨暟鎹€?
## 璧勬簮璇存槑

| 璧勬簮绫诲瀷 | 鍚嶇О | 璇存槑 |
|---|---|---|
| Namespace | devops | 部署到 devops 命名空间 |
| PersistentVolume | gitea-data-pv | Gitea 鏁版嵁鐩綍锛宧ostPath 鎸佷箙鍖?|
| PersistentVolumeClaim | gitea-data-pvc | 鎸傝浇鍒板鍣?`/data` |
| Deployment | gitea | Gitea 鍗曞疄渚嬫湇鍔?|
| Service (ClusterIP) | gitea | 闆嗙兢鍐呴儴璁块棶 |
| Service (NodePort) | gitea-nodeport | 鏆撮湶 HTTP 鍜?SSH |
| Ingress | gitea | 閫氳繃 `gitea.k8s` 璁块棶 HTTP |

## 瀛樺偍鐩綍

娓呭崟榛樿鎶婃暟鎹繚瀛樺埌 Docker Desktop 鍙闂殑瀹夸富鏈鸿矾寰勶細

```text
E:\dockerstore\gitea\data
```

鍦?Pod 鍐呭搴旇矾寰勪负锛?
```text
/data
```

濡傛灉浣犳兂鎹㈢洰褰曪紝淇敼 [gitea-k8s.yaml](./gitea-k8s.yaml) 涓殑 PV `hostPath.path`锛?
```yaml
hostPath:
  path: /mnt/host/e/dockerstore/gitea/data
```

## 閮ㄧ讲

```bash
kubectl apply -f gitea-k8s.yaml

# 绛夊緟 Deployment 瀹屾垚婊氬姩鍙戝竷锛圧olling Update锛?kubectl rollout status deployment/gitea -n devops --timeout=180s

kubectl get pods,svc,ingress,pvc -n devops
```

- rollout 鏄?Kubernetes 涓敤浜庣鐞嗚祫婧愬彂甯冭繃绋嬬殑鍛戒护銆?  - 甯歌瀛愬懡浠わ細
    - kubectl rollout status
    - kubectl rollout history
    - kubectl rollout undo
    - kubectl rollout restart
    - kubectl rollout pause
    - kubectl rollout resume


棰勬湡 Pod 鐘舵€侊細

```text
NAME                         READY   STATUS    RESTARTS   AGE
pod/gitea-xxxxxxxxxx-xxxxx   1/1     Running   0          60s
```

## 璁块棶 Gitea

| 鏂瑰紡 | 鍦板潃 |
|---|---|
| NodePort HTTP | http://localhost:30030 |
| NodePort SSH | ssh://git@localhost:30022 |
| Ingress HTTP | http://gitea.k8s:18080 |

濡傛灉浣跨敤 Ingress锛岄渶瑕佸厛鍦?hosts 鏂囦欢涓坊鍔狅細

```text
127.0.0.1 gitea.k8s
```

## 鍒濆鍖栫鐞嗗憳

棣栨鎵撳紑 `http://localhost:30030` 浼氳繘鍏ュ畨瑁呴〉闈€傛竻鍗曞凡缁忛€氳繃鐜鍙橀噺璁剧疆浜?SQLite 鏁版嵁搴撳拰璁块棶鍦板潃锛岄€氬父鍙渶瑕佺‘璁ら〉闈腑鐨勯厤缃紝鐒跺悗鍒涘缓绠＄悊鍛樿处鍙枫€?
鎺ㄨ崘濉啓锛?
| 閰嶇疆椤?| 鍊?|
|---|---|
| 鏁版嵁搴撶被鍨?| SQLite3 |
| SQLite 鏁版嵁搴撹矾寰?| `/data/gitea/gitea.db` |
| 绔欑偣鏍囬 | Gitea |
| 鏈嶅姟鍣ㄥ煙鍚?| localhost |
| Gitea 鍩虹 URL | `http://localhost:30030/` |
| SSH 鏈嶅姟鍩熷悕 | localhost |
| SSH 鏈嶅姟绔彛 | `30022` |

鍒涘缓绠＄悊鍛樿处鍙峰悗锛屽悗缁氨鐢ㄨ璐﹀彿鐧诲綍銆?
## SSH 鍏嬮殕

鍦?Gitea 椤甸潰涓坊鍔?SSH 鍏挜鍚庯紝鍙互浣跨敤 NodePort 绔彛鍏嬮殕浠撳簱锛?
```bash
git clone ssh://git@localhost:30022/<user>/<repo>.git
```

涔熷彲浠ラ厤缃?SSH alias锛?
```bash
cat >> ~/.ssh/config << EOF
Host gitea-k8s
    HostName localhost
    Port 30022
    User git
EOF

git clone ssh://gitea-k8s/<user>/<repo>.git
```

## 甯哥敤杩愮淮鍛戒护

```bash
# 鏌ョ湅鐘舵€?kubectl get all -n devops

# 鏌ョ湅鏃ュ織
kubectl logs -n devops deployment/gitea --tail=100 -f

# 閲嶅惎
kubectl rollout restart deployment/gitea -n devops

# 杩涘叆瀹瑰櫒
kubectl exec -it -n devops deployment/gitea -- bash

# 鏌ョ湅鏁版嵁鍗?kubectl get pv,pvc -n devops
```

## 澶囦唤鍜屾仮澶?
Gitea 鏁版嵁閮藉湪 `/data`锛屾湰娓呭崟瀵瑰簲瀹夸富鏈虹洰褰曚负锛?
```text
E:\dockerstore\gitea\data
```

绠€鍗曞浠藉彲浠ョ洿鎺ュ鍒惰鐩綍銆備篃鍙互浠?Pod 涓墦鍖咃細

```bash
POD_NAME=$(kubectl get pod -n devops -l app=gitea -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n devops "$POD_NAME" -- tar czf /tmp/gitea-data.tar.gz -C /data .
kubectl cp "devops/$POD_NAME:/tmp/gitea-data.tar.gz" ./gitea-data.tar.gz
```

鎭㈠鏃跺厛鍋滄 Deployment锛屽啀鎶婃暟鎹仮澶嶅埌瀹夸富鏈虹洰褰曟垨 PVC 瀵瑰簲鐩綍锛?
```bash
kubectl scale deployment/gitea -n devops --replicas=0
# 鎭㈠ E:\dockerstore\gitea\data
kubectl scale deployment/gitea -n devops --replicas=1
```

## 甯歌闂

### Pod 涓€鐩?Pending

妫€鏌?PV/PVC 鏄惁缁戝畾锛?
```bash
kubectl get pv gitea-data-pv
kubectl get pvc gitea-data-pvc -n devops
kubectl describe pvc gitea-data-pvc -n devops
```

### 椤甸潰璁块棶姝ｅ父浣?SSH 鍏嬮殕澶辫触

纭 Service 鏆撮湶浜?`30022`锛屽苟涓?Gitea 椤甸潰涓殑 SSH 绔彛閰嶇疆涓?`30022`锛?
```bash
kubectl get svc gitea-nodeport -n devops
```

濡傛灉棣栨瀹夎鏃跺～閿欎簡 SSH 绔彛锛屽彲浠ュ湪 Gitea 绠＄悊椤甸潰鎴?`/data/gitea/conf/app.ini` 涓皟鏁?`SSH_PORT`锛岀劧鍚庨噸鍚細

```bash
kubectl rollout restart deployment/gitea -n devops
```

### 闇€瑕佷慨鏀硅闂煙鍚?
淇敼娓呭崟涓殑鐜鍙橀噺鍚庨噸鏂板簲鐢細

```yaml
GITEA__server__DOMAIN
GITEA__server__SSH_DOMAIN
GITEA__server__ROOT_URL
```

鐒跺悗鎵ц锛?
```bash
kubectl apply -f gitea-k8s.yaml
kubectl rollout restart deployment/gitea -n devops
```

## 娓呯悊璧勬簮

```bash
kubectl delete -f gitea-k8s.yaml
```

PV 浣跨敤 `Retain` 绛栫暐锛屽垹闄よ祫婧愬悗瀹夸富鏈烘暟鎹洰褰曚笉浼氳嚜鍔ㄥ垹闄ゃ€傚闇€褰诲簳娓呯悊锛岃鎵嬪姩鍒犻櫎锛?
```text
E:\dockerstore\gitea\data
```


