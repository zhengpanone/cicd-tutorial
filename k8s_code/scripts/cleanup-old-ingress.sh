#!/usr/bin/env bash
# =============================================================================
# 清理旧 Ingress 资源
# 在所有新 Gateway API 资源(Gateway / HTTPRoute / ReferenceGrant /
# Certificate)apply 并验证通过后,运行本脚本删除旧 Ingress 文件与目录。
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> 删除独立 Ingress 文件..."
rm -v -f \
  "web-app-ingress.yaml" \
  "infra-ingress.yaml" \
  "k8s_demo/ingress.yaml"

echo ""
echo "==> 删除旧子目录..."
rm -v -rf \
  "ingress-nginx/web-app-ingress" \
  "ingress-nginx/cert-manager"

echo ""
echo "==> 完成。剩余 Ingress 资源将由后续 strip 嵌入 Ingress 块处理。"
echo ""
echo "验证:"
grep -rn "kind: Ingress" . || echo "  ✓ 顶层独立 Ingress 文件已清理"