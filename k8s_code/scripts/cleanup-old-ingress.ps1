# =============================================================================
# 清理旧 Ingress 资源(PowerShell 版,Windows 直接跑)
# 在所有新 Gateway API 资源 apply 并验证通过后运行。
#
# 用法(在 k8s_code 目录下):
#   powershell -ExecutionPolicy Bypass -File .\scripts\cleanup-old-ingress.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

# 定位到项目根目录(脚本所在目录的上一级)
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "==> 删除独立 Ingress 文件..." -ForegroundColor Cyan
$files = @(
    "web-app-ingress.yaml",
    "infra-ingress.yaml",
    "k8s_demo\ingress.yaml"
)
foreach ($f in $files) {
    if (Test-Path $f) {
        Remove-Item -LiteralPath $f -Force
        Write-Host "  removed: $f"
    } else {
        Write-Host "  skip (不存在): $f" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "==> 删除旧子目录..." -ForegroundColor Cyan
$dirs = @(
    "ingress-nginx\web-app-ingress",
    "ingress-nginx\cert-manager"
)
foreach ($d in $dirs) {
    if (Test-Path $d) {
        Remove-Item -Recurse -Force -LiteralPath $d
        Write-Host "  removed: $d"
    } else {
        Write-Host "  skip (不存在): $d" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "==> 完成。验证残留 Ingress..." -ForegroundColor Cyan
$hits = Select-String -Path (Get-ChildItem -Recurse -Filter *.yaml).FullName `
    -Pattern "^kind: Ingress$" -ErrorAction SilentlyContinue
if ($hits) {
    Write-Host "  ⚠ 仍有 Ingress 残留:" -ForegroundColor Yellow
    $hits | ForEach-Object { Write-Host "    $($_.Path):$($_.LineNumber)" }
} else {
    Write-Host "  ✓ 无 kind: Ingress 残留" -ForegroundColor Green
}
