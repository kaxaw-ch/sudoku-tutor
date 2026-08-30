<#
.SYNOPSIS
    数独学堂 T-PKG-01 一键打包脚本（宿主机运行，沙箱内禁止执行 flutter 命令）。

.DESCRIPTION
    在宿主 PowerShell 中按顺序执行：
      1) flutter build windows --release
      2) 复制 Release 产物到 dist/SudokuTutor-windows-x64/ 并打绿色版 zip
      3) flutter build apk --debug（build.gradle.kts 的 abiFilters 限定 arm64-v8a + armeabi-v7a，产单个 apk）
      4) 若系统装有 Inno Setup 编译器（ISCC.exe），则编译 installer/sudoku_tutor.iss

    设计原则：
      - 一键可跑：默认参数下不需要任何手工干预
      - 失败即停：任一关键步骤非 0 退出码即中止（$ErrorActionPreference='Stop'）
      - 不主动签名：本期不申请代码签名证书，Setup.exe 触发 SmartScreen 见文档说明
      - 不修改应用源代码：仅做构建 + 物料打包；图标替换见 docs/替换品牌资产说明.md

.PARAMETER SkipWindows
    跳过 Windows 构建（步骤 1-2）。

.PARAMETER SkipAndroid
    跳过 Android apk 构建（步骤 3）。

.PARAMETER SkipInnoSetup
    跳过 Inno Setup 编译（步骤 4），即使本机已装 ISCC。

.EXAMPLE
    pwsh ./scripts/build_release.ps1
    pwsh ./scripts/build_release.ps1 -SkipAndroid
    pwsh ./scripts/build_release.ps1 -SkipWindows -SkipInnoSetup

.NOTES
    路径：本脚本位于 scripts/，项目根为 $PSScriptRoot 的上级目录。
    Flutter 环境：需宿主 PATH 含 flutter（C:/dev/flutter/bin）；FVM 用户请用 `fvm flutter ...`
    替换默认 `& flutter` 为 `& fvm flutter`（自行修改本脚本或在外层调用）。
    PowerShell 兼容：本脚本在 Windows PowerShell 5.1+ 与 PowerShell 7+ 均可运行。
#>

[CmdletBinding()]
param(
    [switch]$SkipWindows,
    [switch]$SkipAndroid,
    [switch]$SkipInnoSetup
)

# ---------------------------------------------------------------------------
# 初始化
# ---------------------------------------------------------------------------
$ErrorActionPreference = 'Stop'
$root        = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$appDir      = Join-Path $root 'app'
$distDir     = Join-Path $root 'dist'
$installerDir = Join-Path $root 'installer'
$windowsRel  = Join-Path $appDir 'build/windows/x64/runner/Release'
$greenDir    = Join-Path $distDir 'SudokuTutor-windows-x64'

if (-not (Test-Path -LiteralPath $appDir))   { throw "未找到 app 目录：$appDir" }
if (-not (Test-Path -LiteralPath $distDir))  { New-Item -ItemType Directory -Path $distDir -Force | Out-Null }

# 解析 pubspec.yaml 中的版本号 "0.1.0+1" → "0.1.0"
$pubspecPath = Join-Path $appDir 'pubspec.yaml'
if (-not (Test-Path -LiteralPath $pubspecPath)) { throw "未找到 $pubspecPath" }
$verMatch = Select-String -Path $pubspecPath -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if (-not $verMatch) { throw "解析版本号失败：$pubspecPath" }
$appVersion = ($verMatch.Matches[0].Groups[1].Value -split '\+')[0]
Write-Host "==> 检测到应用版本: $appVersion" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 步骤 1-2：Windows Release 构建 + 绿色版打包
# ---------------------------------------------------------------------------
if (-not $SkipWindows) {
    Write-Host ""
    Write-Host "==> [1/4] flutter build windows --release" -ForegroundColor Green
    Push-Location -LiteralPath $appDir
    try {
        & flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build windows 失败，退出码 $LASTEXITCODE" }
    } finally { Pop-Location }

    if (-not (Test-Path -LiteralPath $windowsRel)) {
        throw "未找到 Windows Release 产物：$windowsRel（构建可能未完成）"
    }

    Write-Host "==> [2/4] 复制 Release 产物到 dist/ 并 Compress-Archive" -ForegroundColor Green
    if (Test-Path -LiteralPath $greenDir) { Remove-Item -LiteralPath $greenDir -Recurse -Force }
    New-Item -ItemType Directory -Path $greenDir -Force | Out-Null
    Copy-Item -Path (Join-Path $windowsRel '*') -Destination $greenDir -Recurse -Force

    $zipOut = Join-Path $distDir 'SudokuTutor-windows-x64.zip'
    if (Test-Path -LiteralPath $zipOut) { Remove-Item -LiteralPath $zipOut -Force }
    # 用 Get-ChildItem + FullName 显式传递文件列表，兼容 PS 5.1（无 -CompressionLevel 也安全）
    $fileList = (Get-ChildItem -LiteralPath $greenDir -Recurse -File).FullName
    Compress-Archive -Path $fileList -DestinationPath $zipOut
    Write-Host "    绿色版目录 : $greenDir" -ForegroundColor DarkGray
    Write-Host "    绿色版 zip : $zipOut" -ForegroundColor DarkGray
} else {
    Write-Host ""
    Write-Host "==> [1-2/4] 已跳过（-SkipWindows）" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 步骤 3：Android apk debug（abiFilters 已限定 arm64-v8a + armeabi-v7a，不传 --split-per-abi 避免与 splits 冲突）
# ---------------------------------------------------------------------------
if (-not $SkipAndroid) {
    Write-Host ""
    Write-Host "==> [3/4] flutter build apk --debug（abiFilters 限定双 ABI）" -ForegroundColor Green
    Push-Location -LiteralPath $appDir
    try {
        & flutter build apk --debug
        if ($LASTEXITCODE -ne 0) { throw "flutter build apk 失败，退出码 $LASTEXITCODE" }
    } finally { Pop-Location }

    $apkDir = Join-Path $appDir 'build/app/outputs/flutter-apk'
    if (Test-Path -LiteralPath $apkDir) {
        Get-ChildItem -LiteralPath $apkDir -Filter 'app-*-debug.apk' -ErrorAction SilentlyContinue |
            ForEach-Object {
                $sizeMb = '{0:N1}' -f ($_.Length / 1MB)
                Write-Host "    apk: $($_.FullName) ($sizeMb MB)" -ForegroundColor DarkGray
            }
    } else {
        Write-Host "    警告：未找到 apk 输出目录 $apkDir" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "==> [3/4] 已跳过（-SkipAndroid）" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 步骤 4：Inno Setup 编译（探测 ISCC）
# ---------------------------------------------------------------------------
if (-not $SkipInnoSetup) {
    Write-Host ""
    $isccPath = $null
    # 优先探测常见安装路径（不依赖 PATH，PS 5.1 兼容写法）
    foreach ($candidate in @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    )) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { $isccPath = $candidate; break }
    }
    # 退化：PATH 中的 iscc.exe
    if (-not $isccPath) {
        $cmd = Get-Command iscc.exe -ErrorAction SilentlyContinue
        if ($cmd) { $isccPath = $cmd.Source }
    }

    if (-not $isccPath) {
        Write-Host "==> [4/4] 未检测到 ISCC（Inno Setup 编译器），跳过 Setup.exe 生成。" -ForegroundColor Yellow
        Write-Host "    安装 Inno Setup 6 后重跑，或手动执行：" -ForegroundColor DarkGray
        Write-Host "      `"C:\Program Files (x86)\Inno Setup 6\ISCC.exe`" installer\sudoku_tutor.iss" -ForegroundColor DarkGray
    } else {
        Write-Host "==> [4/4] 编译 installer/sudoku_tutor.iss (ISCC: $isccPath)" -ForegroundColor Green
        $issPath = Join-Path $installerDir 'sudoku_tutor.iss'
        if (-not (Test-Path -LiteralPath $issPath)) { throw "未找到 Inno Setup 脚本：$issPath" }
        & "$isccPath" $issPath
        if ($LASTEXITCODE -ne 0) { throw "ISCC 编译失败，退出码 $LASTEXITCODE" }
        $setupExe = Join-Path $distDir "Setup-SudokuTutor-$appVersion.exe"
        Write-Host "    Setup.exe : $setupExe" -ForegroundColor DarkGray
    }
} else {
    Write-Host ""
    Write-Host "==> [4/4] 已跳过（-SkipInnoSetup）" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 汇总
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==> 全部完成 ✅" -ForegroundColor Green
Write-Host "    产物汇总：" -ForegroundColor Cyan
Write-Host "      绿色版目录 : $greenDir"
Write-Host "      绿色版 zip : $(Join-Path $distDir 'SudokuTutor-windows-x64.zip')"
Write-Host "      APK        : $(Join-Path $appDir 'build/app/outputs/flutter-apk/app-debug.apk')"
Write-Host "      Setup.exe  : $(Join-Path $distDir "Setup-SudokuTutor-$appVersion.exe")  (若本机装有 ISCC)"
Write-Host ""
Write-Host "    SmartScreen 提示：未签名 exe 首次运行会触发拦截，" -ForegroundColor DarkYellow -NoNewline
Write-Host "见 docs/10-T-PKG01-打包说明.md §3。" -ForegroundColor DarkYellow