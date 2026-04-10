
创建token

```
kubectl -n kubernetes-dashboard get secret admin-user-token \
-o jsonpath="{.data.token}" | base64 -d

microk8s kubectl -n kubernetes-dashboard create token admin-user --duration=8760h
```