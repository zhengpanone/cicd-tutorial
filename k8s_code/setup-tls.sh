#!/bin/bash
# 为所有 *.k8s 域名生成一张自签名 TLS 证书（SAN 多域名），创建共享 Secret
# 使用方法: bash setup-tls.sh

set -e

HOSTS=("gin.k8s" "express.k8s" "springboot.k8s")
SECRET_NAME="web-app-tls"
NAMESPACE="web-app"
CERT_DIR="./certs"
DAYS=365

echo "==> 创建证书目录..."
mkdir -p "$CERT_DIR"

# 构建 SAN 字符串: DNS:gin.k8s,DNS:express.k8s,DNS:springboot.k8s
SAN=""
for h in "${HOSTS[@]}"; do
  if [ -z "$SAN" ]; then
    SAN="DNS:${h}"
  else
    SAN="${SAN},DNS:${h}"
  fi
done

echo "==> 生成自签名 TLS 多域名证书 (有效期 ${DAYS} 天)..."
echo "    域名: ${HOSTS[*]}"
echo "    SAN:  ${SAN}"

openssl req -x509 -nodes -days "$DAYS" -newkey rsa:2048 \
  -keyout "$CERT_DIR/tls.key" \
  -out "$CERT_DIR/tls.crt" \
  -subj "/CN=${HOSTS[0]}/O=Dev/C=CN" \
  -addext "subjectAltName=${SAN}"

echo "==> 证书已生成:"
echo "    私钥: $CERT_DIR/tls.key"
echo "    证书: $CERT_DIR/tls.crt"

echo "==> 验证证书域名..."
openssl x509 -in "$CERT_DIR/tls.crt" -noout -ext subjectAltName

echo "==> 创建 Kubernetes TLS Secret (${SECRET_NAME})..."
kubectl create secret tls "$SECRET_NAME" \
  --cert="$CERT_DIR/tls.crt" \
  --key="$CERT_DIR/tls.key" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> 验证 Secret..."
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE"

echo ""
echo "完成! 所有应用共用同一个 Secret: ${SECRET_NAME}"
echo ""
echo "重新部署各应用:"
echo "  kubectl apply -f k8s_code/my-gin-app/my-gin-app-k8s.yaml"
echo "  kubectl apply -f k8s_code/my-express-app/my-express-app-k8s.yaml"
echo "  kubectl apply -f k8s_code/my-springboot-app/my-springboot-k8s.yaml"
echo ""
echo "访问测试:"
for h in "${HOSTS[@]}"; do
  echo "  HTTP:  curl http://${h}"
  echo "  HTTPS: curl -k https://${h}"
done
echo ""
echo "提示: 如需浏览器信任，可一次性导入证书:"
echo "  Windows: certutil -addstore -f \"ROOT\" $CERT_DIR/tls.crt"
echo "  WSL2:    sudo cp $CERT_DIR/tls.crt /usr/local/share/ca-certificates/web-app-k8s.crt && sudo update-ca-certificates"
