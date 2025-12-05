测试mysql-service 是否可用
```bash
kubectl run mysql-test --image=mysql:8.0.24 --rm -it --restart=Never -- mysql -h mysql-service -P 3306 -uroot -proot -e "SELECT 1;"
```