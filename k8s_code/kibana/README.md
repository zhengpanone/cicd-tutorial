# Kibana 部署

Kibana 8.13.4，连接 Elasticsearch 提供日志分析和可视化。

## 资源清单

| 资源 | 名称 | 说明 |
|------|------|------|
| Deployment | kibana | 镜像 kibana:8.13.4 |
| Service (NodePort) | kibana | 端口 5601，NodePort 30561 |

所有资源部署在 `elk` 命名空间。

## 部署

```bash
kubectl apply -f kibana-k8s.yaml
```

## 配置

通过环境变量指定 Elasticsearch 地址：

```yaml
env:
  - name: ELASTICSEARCH_HOSTS
    value: http://elasticsearch.elk.svc.cluster.local:9200
  - name: I18N_LOCALE
    value: zh-CN
```

## 访问

Ingress 域名：

```bash
http://kibana.k8s:18080
https://kibana.k8s:18443
```

NodePort 直连：`http://localhost:30561`

需先在 hosts 文件添加 `127.0.0.1 kibana.k8s`。TLS 证书由 `ingress-nginx/cert-manager/tls-resources.yaml` 中的 `efk-tls` 自动管理。
