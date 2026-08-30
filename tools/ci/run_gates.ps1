# ============================================================================
#  CI 门禁一键执行脚本（Windows PowerShell）—— doc 07 T-QA-01 ⛔
#
#  执行顺序（任一步失败即中断并返回非 0）：
#    1. 三包 pub get
#    2. 分层约束扫描  tools/ci/check_layering.dart（R1–R6）
#    3. 静态分析      dart analyze（两个 package）+ flutter analyze（app）
#    4. 单元测试      dart test（sudoku_core / sudoku_cli）
#    5. 覆盖率门槛    sudoku_core 行覆盖率 ≥ 阈值（默认 90%，批次 A 可用 -SkipCoverage 跳过）
#
#  用法：
#    pwsh -File tools/ci/run_gates.ps1
#    pwsh -File tools/ci/run_gates.ps1 -SkipCoverage
#    pwsh -File tools/ci/run_gates.ps1 -CoverageThreshold 90
#
#  ⚠️ 本脚本需要 Flutter / Dart SDK 已在 PATH 中（见 scripts/verify_env.ps1）。
# ============================================================================

[CmdletBinding()]
param(
    [switch]$SkipCoverage,
    [switch]$SkipApp,
    [int]$CoverageThreshold = 90
)

$ErrorActionPreference = 'Stop'
$script:StepIndex = 0

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $RepoRoot

function Write-Step {
    param([string]$Title)
    $script:StepIndex++
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor DarkGray
    Write-Host ("步骤 {0} · {1}" -f $script:StepIndex, $Title) -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor DarkGray
}

function Invoke-Gate {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    & $Action
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("❌ 门禁失败：{0}（退出码 {1}）" -f $Name, $LASTEXITCODE) -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host ("✅ 通过：{0}" -f $Name) -ForegroundColor Green
}

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------- 环境检查
Write-Step '环境检查'
if (-not (Test-CommandExists 'dart')) {
    Write-Host '❌ 未找到 dart，请先执行 scripts/setup_windows.ps1' -ForegroundColor Red
    exit 2
}
dart --version
$hasFlutter = Test-CommandExists 'flutter'
if (-not $hasFlutter) {
    Write-Host '⚠️  未找到 flutter，将跳过 app 相关门禁' -ForegroundColor Yellow
    $SkipApp = $true
}

# ---------------------------------------------------------------- 1. pub get
Write-Step '依赖解析（pub get）'
Invoke-Gate 'pub get · sudoku_core' { dart pub get --directory packages/sudoku_core }
Invoke-Gate 'pub get · sudoku_cli'  { dart pub get --directory packages/sudoku_cli }
if (-not $SkipApp) {
    Invoke-Gate 'pub get · app' { flutter pub get --directory app }
}

# ---------------------------------------------------------------- 2. 分层门禁
Write-Step '分层约束扫描（R1–R6）'
Invoke-Gate '分层约束' { dart run tools/ci/check_layering.dart --root $RepoRoot }

# ---------------------------------------------------------------- 3. 静态分析
Write-Step '静态分析（零告警）'
Invoke-Gate 'analyze · sudoku_core' { dart analyze --fatal-infos --fatal-warnings packages/sudoku_core }
Invoke-Gate 'analyze · sudoku_cli'  { dart analyze --fatal-infos --fatal-warnings packages/sudoku_cli }
if (-not $SkipApp) {
    Push-Location app
    try {
        Invoke-Gate 'analyze · app' { flutter analyze --fatal-infos --fatal-warnings }
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------- 4. 单元测试
Write-Step '单元测试'
Push-Location packages/sudoku_core
try {
    Invoke-Gate 'test · sudoku_core' { dart test }
} finally {
    Pop-Location
}

if (Test-Path 'packages/sudoku_cli/test') {
    Push-Location packages/sudoku_cli
    try {
        Invoke-Gate 'test · sudoku_cli' { dart test }
    } finally {
        Pop-Location
    }
} else {
    Write-Host 'ℹ️  packages/sudoku_cli/test 尚不存在，跳过（批次 D 补齐）' -ForegroundColor Yellow
}

if (-not $SkipApp) {
    Push-Location app
    try {
        Invoke-Gate 'test · app' { flutter test }
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------- 5. 覆盖率
if ($SkipCoverage) {
    Write-Host ''
    Write-Host 'ℹ️  已按参数跳过覆盖率门槛（批次 A 允许；批次 B 起必须开启）' -ForegroundColor Yellow
} else {
    Write-Step ("覆盖率门槛（sudoku_core ≥ {0}%）" -f $CoverageThreshold)
    Push-Location packages/sudoku_core
    try {
        Invoke-Gate '收集覆盖率' { dart test --coverage=coverage }
        Invoke-Gate '生成 lcov' {
            dart run coverage:format_coverage `
                --lcov --in=coverage --out=coverage/lcov.info `
                --report-on=lib --packages=.dart_tool/package_config.json
        }

        $lcovPath = 'coverage/lcov.info'
        if (-not (Test-Path $lcovPath)) {
            Write-Host '❌ 未生成 coverage/lcov.info' -ForegroundColor Red
            exit 1
        }
        $lines = Get-Content $lcovPath
        $found = ($lines | Where-Object { $_ -like 'LF:*' } |
            ForEach-Object { [int]($_ -replace 'LF:', '') } |
            Measure-Object -Sum).Sum
        $hit = ($lines | Where-Object { $_ -like 'LH:*' } |
            ForEach-Object { [int]($_ -replace 'LH:', '') } |
            Measure-Object -Sum).Sum
        if ($found -eq 0) {
            Write-Host '❌ 覆盖率数据为空' -ForegroundColor Red
            exit 1
        }
        $percent = [math]::Round(100.0 * $hit / $found, 2)
        Write-Host ("行覆盖率：{0}% （{1}/{2}）" -f $percent, $hit, $found)
        if ($percent -lt $CoverageThreshold) {
            Write-Host ("❌ 低于门槛 {0}%" -f $CoverageThreshold) -ForegroundColor Red
            exit 1
        }
        Write-Host '✅ 通过：覆盖率门槛' -ForegroundColor Green
    } finally {
        Pop-Location
    }
}

Write-Host ''
Write-Host ('=' * 72) -ForegroundColor DarkGray
Write-Host '🎉 全部 CI 门禁通过' -ForegroundColor Green
Write-Host ('=' * 72) -ForegroundColor DarkGray
exit 0
