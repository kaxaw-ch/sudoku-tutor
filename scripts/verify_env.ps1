#Requires -Version 5.1
<#
.SYNOPSIS
    数独教学 App —— Windows 开发环境验证脚本

.DESCRIPTION
    执行 `flutter doctor -v` 并解析其输出，结合独立的工具链探测，明确给出两个结论：
      A) 本机能否构建 Windows 桌面产物 (flutter build windows)
      B) 本机能否构建 Android 产物   (flutter build apk --debug)

    脚本会在 scripts 目录下生成一份完整报告文件 env_report_<时间戳>.txt，
    请把该文件回传给开发方，用于确认是否可以进入 M0 冒烟验证。

.PARAMETER ReportPath
    报告输出路径。默认为脚本所在目录下的 env_report_<yyyyMMdd_HHmmss>.txt。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\verify_env.ps1

.NOTES
    退出码：
       0 = Windows 与 Android 均可构建
      10 = 仅 Windows 可构建
      20 = 仅 Android 可构建
      30 = 两者均不可构建
      40 = 未找到 Flutter SDK
#>

[CmdletBinding()]
param(
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$ProgressPreference = 'SilentlyContinue'

$script:Lines = New-Object System.Collections.ArrayList

function Emit {
    param([string]$Text = '', [string]$Color = 'Gray')
    Write-Host $Text -ForegroundColor $Color
    $null = $script:Lines.Add($Text)
}
function EmitTitle {
    param([string]$Text)
    Emit '' 'Gray'
    Emit ('=' * 74) 'Cyan'
    Emit ('  ' + $Text) 'Cyan'
    Emit ('=' * 74) 'Cyan'
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = (Get-Location).Path }
    $ReportPath = Join-Path $scriptDir ('env_report_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
}

EmitTitle '数独教学 App —— 开发环境验证报告'
Emit ('生成时间 : ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Emit ('计算机名 : ' + $env:COMPUTERNAME)
Emit ('用户     : ' + $env:USERNAME)
try {
    Emit ('操作系统 : ' + (Get-CimInstance Win32_OperatingSystem).Caption + '  (' + [Environment]::OSVersion.Version + ')')
} catch {
    Emit ('操作系统 : ' + [Environment]::OSVersion.VersionString)
}
Emit ('PowerShell : ' + $PSVersionTable.PSVersion)

# ---------------------------------------------------------------------------
# 一、基础工具链直接探测（不依赖 flutter doctor）
# ---------------------------------------------------------------------------
EmitTitle '一、基础工具链直接探测'

# 按“显示宽度”补空格：中文/全角字符按 2 列计算，保证控制台表格对齐
function PadName {
    param([string]$Text, [int]$Width = 24)
    $w = 0
    foreach ($ch in $Text.ToCharArray()) {
        if ([int][char]$ch -gt 0x2E7F) { $w += 2 } else { $w += 1 }
    }
    $pad = $Width - $w
    if ($pad -lt 1) { $pad = 1 }
    return ($Text + (' ' * $pad))
}

function Probe {
    param([string]$Name, [string]$Command, [string]$VersionArg = '--version')
    $cmd = Get-Command -Name $Command -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        Emit ('  [缺失] ' + (PadName $Name) + '未在 PATH 中找到 ' + $Command) 'Red'
        return $false
    }
    $ver = ''
    try {
        $raw = & $Command $VersionArg 2>&1
        if ($raw -is [array]) { $ver = ($raw | Select-Object -First 1) } else { $ver = $raw }
    } catch { $ver = '(版本读取失败)' }
    Emit ('  [具备] ' + (PadName $Name) + ($ver -replace '\s+', ' ')) 'Green'
    return $true
}

$hasFlutter = Probe 'Flutter SDK' 'flutter'
$hasDart    = Probe 'Dart SDK'    'dart'
$hasGit     = Probe 'Git'         'git'
$hasJava    = Probe 'Java (JRE)'  'java' '-version'
$hasJavac   = Probe 'Java 编译器'  'javac' '-version'
$hasAdb     = Probe 'adb'         'adb'

# JAVA_HOME
if ([string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
    Emit ('  [缺失] ' + (PadName 'JAVA_HOME') + '未设置') 'Red'
    $hasJavaHome = $false
} else {
    $javacPath = Join-Path $env:JAVA_HOME 'bin\javac.exe'
    if (Test-Path -LiteralPath $javacPath) {
        Emit ('  [具备] ' + (PadName 'JAVA_HOME') + $env:JAVA_HOME) 'Green'
        $hasJavaHome = $true
    } else {
        Emit ('  [异常] ' + (PadName 'JAVA_HOME') + $env:JAVA_HOME + ' 下无 bin\javac.exe（可能是 JRE 而非 JDK）') 'Red'
        $hasJavaHome = $false
    }
}

# Android SDK
$androidSdk = $env:ANDROID_HOME
if ([string]::IsNullOrWhiteSpace($androidSdk)) { $androidSdk = $env:ANDROID_SDK_ROOT }
if ([string]::IsNullOrWhiteSpace($androidSdk)) {
    Emit ('  [缺失] ' + (PadName 'ANDROID_HOME') + '未设置') 'Red'
    $hasAndroidSdk = $false
} elseif (Test-Path -LiteralPath $androidSdk) {
    Emit ('  [具备] ' + (PadName 'ANDROID_HOME') + $androidSdk) 'Green'
    $hasAndroidSdk = $true
    foreach ($sub in @('platform-tools', 'platforms', 'build-tools')) {
        $subPath = Join-Path $androidSdk $sub
        if (Test-Path -LiteralPath $subPath) {
            $items = @(Get-ChildItem -LiteralPath $subPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
            $desc = ''
            if ($sub -ne 'platform-tools') { $desc = ' -> ' + ($items -join ', ') }
            Emit ('         +- ' + (PadName $sub 16) + '已安装' + $desc) 'Green'
        } else {
            Emit ('         +- ' + (PadName $sub 16) + '缺失') 'Yellow'
        }
    }
} else {
    Emit ('  [异常] ' + (PadName 'ANDROID_HOME') + '路径不存在: ' + $androidSdk) 'Red'
    $hasAndroidSdk = $false
}

# Visual Studio C++
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$hasVcTools = $false
$vsInstallPath = ''
if (Test-Path -LiteralPath $vswhere) {
    try {
        $vsInstallPath = (& $vswhere -products '*' -requires 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' -property installationPath -latest 2>$null | Select-Object -First 1)
    } catch { }
}
if (-not [string]::IsNullOrWhiteSpace($vsInstallPath)) {
    $hasVcTools = $true
    Emit ('  [具备] ' + (PadName 'Visual Studio C++') + $vsInstallPath) 'Green'
    $ninja = Join-Path $vsInstallPath 'Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe'
    if (Test-Path -LiteralPath $ninja) {
        Emit ('         +- ' + (PadName 'Ninja' 16) + '已随 VS 安装') 'Green'
    } else {
        Emit ('         +- ' + (PadName 'Ninja' 16) + '未在 VS 目录中找到（请确认已勾选「适用于 Windows 的 C++ CMake 工具」）') 'Yellow'
    }
} else {
    Emit ('  [缺失] ' + (PadName 'Visual Studio C++') + '未检测到含 MSVC v143 工具集的 Visual Studio') 'Red'
}

# Windows SDK
$winKits = 'C:\Program Files (x86)\Windows Kits\10\Include'
if (Test-Path -LiteralPath $winKits) {
    $sdkVers = @(Get-ChildItem -LiteralPath $winKits -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    Emit ('  [具备] ' + (PadName 'Windows SDK') + ($sdkVers -join ', ')) 'Green'
} else {
    Emit ('  [缺失] ' + (PadName 'Windows SDK') + $winKits + ' 不存在') 'Red'
}

# 磁盘
try {
    $d = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='" + $env:SystemDrive + "'")
    $freeGB = [math]::Round($d.FreeSpace / 1GB, 1)
    $color = 'Green'
    if ($freeGB -lt 40) { $color = 'Yellow' }
    Emit ('  [信息] ' + (PadName '系统盘剩余空间') + $freeGB + ' GB（建议 >= 40 GB）') $color
} catch { }

# ---------------------------------------------------------------------------
# 二、flutter doctor -v
# ---------------------------------------------------------------------------
EmitTitle '二、flutter doctor -v 原始输出'

$doctorText = ''
$doctorEntries = @{}

if (-not $hasFlutter) {
    Emit '  未找到 flutter 命令，跳过 flutter doctor。' 'Red'
    Emit '  请先运行 setup_windows.ps1，并【重新打开终端】使 PATH 生效。' 'Red'
} else {
    Emit '  正在执行 flutter doctor -v（首次执行可能需要 1-3 分钟）...' 'Gray'
    try {
        $doctorRaw = & flutter doctor -v 2>&1
        $doctorText = ($doctorRaw | Out-String)
    } catch {
        $doctorText = '执行 flutter doctor 失败: ' + $_.Exception.Message
    }
    foreach ($line in ($doctorText -split "`r?`n")) {
        Emit ('  ' + $line)
        $m = [regex]::Match($line, '^\s*\[(.)\]\s+(.+?)\s*$')
        if ($m.Success) {
            $mark  = $m.Groups[1].Value
            $title = $m.Groups[2].Value
            $status = 'FAIL'
            if ($mark -eq [char]0x221A -or $mark -eq [char]0x2713 -or $mark -eq 'v' -or $mark -eq '+') { $status = 'OK' }
            elseif ($mark -eq '!') { $status = 'WARN' }
            $key = ''
            if     ($title -match '^Flutter\b')            { $key = 'flutter' }
            elseif ($title -match '^Windows Version')      { $key = 'winver' }
            elseif ($title -match '^Android toolchain')    { $key = 'android' }
            elseif ($title -match '^Visual Studio')        { $key = 'vs' }
            elseif ($title -match '^Android Studio')       { $key = 'androidstudio' }
            elseif ($title -match '^Chrome')               { $key = 'chrome' }
            elseif ($title -match '^Connected device')     { $key = 'device' }
            elseif ($title -match '^Network resources')    { $key = 'network' }
            if ($key -ne '') {
                $doctorEntries[$key] = [PSCustomObject]@{ Status = $status; Title = $title }
            }
        }
    }
}

function Get-DoctorStatus {
    param([string]$Key)
    if ($doctorEntries.ContainsKey($Key)) { return $doctorEntries[$Key].Status }
    return 'MISSING'
}

$licenseIssue = ($doctorText -match 'android-licenses' -or $doctorText -match 'license status unknown' -or $doctorText -match 'licenses not accepted')

# ---------------------------------------------------------------------------
# 三、结论
# ---------------------------------------------------------------------------
EmitTitle '三、结论'

$flutterOk = ($hasFlutter -and ((Get-DoctorStatus 'flutter') -eq 'OK' -or (Get-DoctorStatus 'flutter') -eq 'WARN'))

# --- Windows 构建能力 ---
$vsDoctor = Get-DoctorStatus 'vs'
$canWindows = $false
$winReasons = New-Object System.Collections.ArrayList
if (-not $hasFlutter)  { $null = $winReasons.Add('未安装 Flutter SDK') }
if (-not $hasVcTools)  { $null = $winReasons.Add('未安装 Visual Studio 「使用 C++ 的桌面开发」工作负载（缺 MSVC / Windows SDK / Ninja）') }
if ($hasFlutter -and $vsDoctor -eq 'FAIL') { $null = $winReasons.Add('flutter doctor 报告 Visual Studio 项不通过') }
if ($winReasons.Count -eq 0) { $canWindows = $true }

# --- Android 构建能力 ---
$androidDoctor = Get-DoctorStatus 'android'
$canAndroid = $false
$androidReasons = New-Object System.Collections.ArrayList
if (-not $hasFlutter)     { $null = $androidReasons.Add('未安装 Flutter SDK') }
if (-not $hasJavaHome)    { $null = $androidReasons.Add('JAVA_HOME 未指向一个可用的 JDK（需 JDK 17+，不能是 JRE）') }
if (-not $hasAndroidSdk)  { $null = $androidReasons.Add('未配置 Android SDK（ANDROID_HOME）') }
if ($hasFlutter -and $androidDoctor -eq 'FAIL') { $null = $androidReasons.Add('flutter doctor 报告 Android toolchain 项不通过') }
$androidLicensePending = $false
if ($androidReasons.Count -eq 0) {
    $canAndroid = $true
    if ($androidDoctor -eq 'WARN' -and $licenseIssue) { $androidLicensePending = $true }
}

Emit ''
Emit ('  【能否构建 Windows 桌面产物 (flutter build windows)】') 'White'
if ($canWindows) {
    Emit '     ==> 可以 ✔' 'Green'
} else {
    Emit '     ==> 不可以 ✘' 'Red'
    foreach ($r in $winReasons) { Emit ('        - ' + $r) 'Red' }
}

Emit ''
Emit ('  【能否构建 Android 产物 (flutter build apk --debug)】') 'White'
if ($canAndroid -and -not $androidLicensePending) {
    Emit '     ==> 可以 ✔' 'Green'
} elseif ($canAndroid -and $androidLicensePending) {
    Emit '     ==> 基本就绪，但【许可协议未接受】' 'Yellow'
    Emit '        请执行：flutter doctor --android-licenses  并逐条输入 y' 'Yellow'
} else {
    Emit '     ==> 不可以 ✘' 'Red'
    foreach ($r in $androidReasons) { Emit ('        - ' + $r) 'Red' }
}

Emit ''
Emit '  【本期不涉及】macOS / iOS 产物：需 macOS + Xcode，Windows 机器物理不可构建。' 'Gray'

# --- 下一步建议 ---
EmitTitle '四、下一步'
if ($canWindows -and $canAndroid -and -not $androidLicensePending) {
    Emit '  环境已完全就绪，可以直接进入 M0 冒烟验证：' 'Green'
    Emit '     flutter create --org sudututor.app --platforms=windows,android sudoku_tutor' 'Green'
    Emit '     cd sudoku_smoke' 'Green'
    Emit '     flutter build windows' 'Green'
    Emit '     flutter build apk --debug' 'Green'
} else {
    Emit '  环境尚未就绪。请按上方「不可以」列出的原因逐条补齐后重新运行本脚本。' 'Yellow'
    Emit '  多数情况下重新运行 setup_windows.ps1 即可自动补齐。' 'Yellow'
}
Emit ''
Emit ('  完整报告已保存到: ' + $ReportPath) 'Cyan'
Emit '  请把该文件回传给开发方。' 'Cyan'
Emit ''

# --- 写报告文件 ---
try {
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($ReportPath, ($script:Lines -join [Environment]::NewLine), $utf8Bom)
} catch {
    Write-Host ('报告写入失败: ' + $_.Exception.Message) -ForegroundColor Red
}

# --- 退出码 ---
if ($canWindows -and $canAndroid)         { exit 0 }
elseif ($canWindows -and -not $canAndroid) { exit 10 }
elseif (-not $canWindows -and $canAndroid) { exit 20 }
elseif (-not $hasFlutter)                  { exit 40 }
else                                       { exit 30 }
