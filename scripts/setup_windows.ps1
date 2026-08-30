#Requires -Version 5.1
<#
.SYNOPSIS
    数独教学 App —— Windows 开发环境一键安装脚本

.DESCRIPTION
    本脚本负责安装 Flutter 跨端开发（Windows 桌面 + Android）所需的全部工具链：
      1. Git                        （若缺失，用 winget 安装）
      2. Flutter SDK                （官方 zip 直下，可锁定版本）
      3. Visual Studio Build Tools 2022 + 「使用 C++ 的桌面开发」工作负载
                                    （Windows exe 构建必需，含 MSVC / Windows SDK / Ninja / CMake；不含 IDE，可用 VS Code 编辑）
      4. Microsoft Build of OpenJDK 17（微软 CDN，Android Gradle 构建必需；国内访问比 GitHub 的 Adoptium 更稳定）
      5. Android SDK cmdline-tools + platform-tools + build-tools + platform
      6. 环境变量（PATH / JAVA_HOME / ANDROID_HOME / ANDROID_SDK_ROOT）

    脚本可重复执行（幂等）：已安装的组件会自动跳过。

.PARAMETER InstallRoot
    工具链根目录。默认 C:\dev。
    ⚠️ 请勿使用含空格或中文的路径（如 C:\Program Files、C:\用户\...），Flutter 与 Gradle 对此支持很差。

.PARAMETER FlutterVersion
    锁定的 Flutter 版本号（如 3.35.4）。留空则自动使用官方 stable 频道当前版本。

.PARAMETER CmdlineToolsUrl
    Android cmdline-tools 压缩包下载地址。若默认地址失效，请到
    https://developer.android.com/studio#command-line-tools-only 复制最新地址后用本参数传入。

.PARAMETER AutoAcceptAndroidLicenses
    自动接受 Android SDK 许可协议（等价于逐条输入 y）。
    ⚠️ 使用该开关即表示您本人已阅读并同意 Google 的 Android SDK 许可条款。不加此开关则需手动接受。

.PARAMETER UseChinaMirror
    使用中国大陆镜像加速 Flutter / pub 下载（网络不畅时尝试）。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\setup_windows.ps1

.EXAMPLE
    # 只补装 Android 部分，并自动接受许可
    powershell -ExecutionPolicy Bypass -File .\setup_windows.ps1 -SkipFlutter -SkipVisualStudio -SkipJdk -AutoAcceptAndroidLicenses

.NOTES
    必须以【管理员身份】运行 PowerShell，否则 Visual Studio 安装会失败。
    安装过程中会出现 UAC 弹窗，需要人工点击「是」。
#>

[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\dev',
    [string]$FlutterVersion = '',
    [string]$CmdlineToolsUrl = 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip',
    [string]$AndroidPlatform = 'android-35',
    [string]$AndroidBuildTools = '35.0.0',
    [switch]$SkipGit,
    [switch]$SkipFlutter,
    [switch]$SkipVisualStudio,
    [switch]$SkipJdk,
    [switch]$SkipAndroid,
    [switch]$AutoAcceptAndroidLicenses,
    [switch]$UseChinaMirror
)

# ----------------------------------------------------------------------------
# 0. 基础设置
# ----------------------------------------------------------------------------
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
$ProgressPreference = 'SilentlyContinue'   # 关闭进度条，Invoke-WebRequest 下载大文件会快 5-10 倍

$script:Results = New-Object System.Collections.ArrayList
$script:DownloadDir = Join-Path $env:TEMP 'sudoku_env_setup'

function Write-Step {
    param([string]$Text)
    Write-Host ''
    Write-Host ('=' * 74) -ForegroundColor Cyan
    Write-Host ("  " + $Text) -ForegroundColor Cyan
    Write-Host ('=' * 74) -ForegroundColor Cyan
}
function Write-Info { param([string]$Text) Write-Host ("    " + $Text) -ForegroundColor Gray }
function Write-Ok   { param([string]$Text) Write-Host ("  [OK]   " + $Text) -ForegroundColor Green }
function Write-Warn2{ param([string]$Text) Write-Host ("  [WARN] " + $Text) -ForegroundColor Yellow }
function Write-Err2 { param([string]$Text) Write-Host ("  [FAIL] " + $Text) -ForegroundColor Red }

function Add-Result {
    param([string]$Component, [string]$Status, [string]$Detail)
    $null = $script:Results.Add([PSCustomObject]@{
        组件 = $Component
        结果 = $Status
        说明 = $Detail
    })
}

function Test-IsAdmin {
    try {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $pr = New-Object System.Security.Principal.WindowsPrincipal($id)
        return $pr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Test-CommandExists {
    param([string]$Name)
    $c = Get-Command -Name $Name -ErrorAction SilentlyContinue
    return ($null -ne $c)
}

function Add-UserPath {
    param([string]$PathToAdd)
    if ([string]::IsNullOrWhiteSpace($PathToAdd)) { return }
    $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($null -eq $cur) { $cur = '' }
    $parts = @($cur.Split(';') | Where-Object { $_ -ne '' })
    $found = $false
    foreach ($p in $parts) {
        if ($p.TrimEnd('\') -ieq $PathToAdd.TrimEnd('\')) { $found = $true }
    }
    if (-not $found) {
        $newPath = (@($parts) + @($PathToAdd)) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Info ("已写入用户 PATH: " + $PathToAdd)
    }
    if (@($env:Path.Split(';')) -notcontains $PathToAdd) {
        $env:Path = $env:Path + ';' + $PathToAdd
    }
}

function Set-UserEnv {
    param([string]$Name, [string]$Value)
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    Set-Item -Path ("Env:" + $Name) -Value $Value
    Write-Info ("已设置环境变量 " + $Name + " = " + $Value)
}

function Invoke-Download {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutFile,
        [int]$Retry = 3
    )
    if (Test-Path -LiteralPath $OutFile) {
        $existing = Get-Item -LiteralPath $OutFile
        if ($existing.Length -gt 1MB) {
            Write-Info ("已存在本地缓存，跳过下载: " + $OutFile)
            return $true
        }
        Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
    }
    for ($i = 1; $i -le $Retry; $i++) {
        try {
            Write-Info ("下载中 ({0}/{1})：{2}" -f $i, $Retry, $Url)
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -TimeoutSec 3600
            if ((Test-Path -LiteralPath $OutFile) -and ((Get-Item -LiteralPath $OutFile).Length -gt 0)) {
                Write-Info ("下载完成，大小 {0:N1} MB" -f ((Get-Item -LiteralPath $OutFile).Length / 1MB))
                return $true
            }
        } catch {
            Write-Warn2 ("下载失败：" + $_.Exception.Message)
            Start-Sleep -Seconds 5
        }
    }
    return $false
}

function Expand-ZipTo {
    param([string]$ZipPath, [string]$Destination)
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $Destination)) {
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $Destination)
        return $true
    } catch {
        Write-Warn2 ("内置解压失败，回退 Expand-Archive：" + $_.Exception.Message)
        try {
            Expand-Archive -LiteralPath $ZipPath -DestinationPath $Destination -Force
            return $true
        } catch {
            Write-Err2 ("解压失败：" + $_.Exception.Message)
            return $false
        }
    }
}

function Invoke-Winget {
    param([string]$PackageId, [string]$OverrideArgs = '')
    if (-not (Test-CommandExists 'winget')) {
        Write-Err2 '未检测到 winget。请先从 Microsoft Store 安装「应用安装程序 (App Installer)」。'
        return $false
    }
    $argList = @('install', '--id', $PackageId, '--exact', '--silent',
                 '--accept-source-agreements', '--accept-package-agreements')
    if ($OverrideArgs -ne '') {
        $argList += @('--override', $OverrideArgs)
    }
    Write-Info ("执行: winget " + ($argList -join ' '))
    $proc = Start-Process -FilePath 'winget' -ArgumentList $argList -NoNewWindow -Wait -PassThru
    # winget 退出码：0 成功；-1978335189 (0x8A15002B) 已安装无可用升级
    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq -1978335189) { return $true }
    Write-Warn2 ("winget 返回退出码 " + $proc.ExitCode)
    return $false
}

# ----------------------------------------------------------------------------
# 1. 预检
# ----------------------------------------------------------------------------
Write-Step '步骤 0 / 7 —— 环境预检'

Write-Info ("操作系统: " + (Get-CimInstance Win32_OperatingSystem).Caption + " (" + [Environment]::OSVersion.Version + ")")
Write-Info ("PowerShell 版本: " + $PSVersionTable.PSVersion)

$isAdmin = Test-IsAdmin
if ($isAdmin) {
    Write-Ok '当前为管理员会话。'
} else {
    Write-Warn2 '当前【不是】管理员会话！Visual Studio 安装步骤将失败。'
    Write-Warn2 '请关闭本窗口，右键 PowerShell -> 「以管理员身份运行」后重新执行。'
    if (-not $SkipVisualStudio) {
        $ans = Read-Host '仍要继续吗？(输入 y 继续 / 其它键退出)'
        if ($ans -ne 'y') { exit 1 }
    }
}

$sysDrive = ($env:SystemDrive)
$diskFreeGB = 0
try {
    $d = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='" + $sysDrive + "'")
    $diskFreeGB = [math]::Round($d.FreeSpace / 1GB, 1)
} catch { }
Write-Info ("系统盘 " + $sysDrive + " 剩余空间: " + $diskFreeGB + " GB")
if ($diskFreeGB -lt 40) {
    Write-Warn2 '剩余空间不足 40 GB。完整工具链约需 20-28 GB，加上构建缓存建议预留 40 GB 以上。'
} else {
    Write-Ok '磁盘空间充足。'
}

if ($InstallRoot -match '\s' -or $InstallRoot -match '[^\x00-\x7F]') {
    Write-Err2 ("安装根目录含空格或非 ASCII 字符，Flutter/Gradle 会出问题：" + $InstallRoot)
    Write-Err2 '请改用如 C:\dev 这样的纯英文无空格路径。'
    exit 1
}
if (-not (Test-Path -LiteralPath $InstallRoot)) {
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $script:DownloadDir)) {
    New-Item -ItemType Directory -Path $script:DownloadDir -Force | Out-Null
}
Write-Ok ("安装根目录: " + $InstallRoot)
Write-Info ("下载缓存目录: " + $script:DownloadDir)

if ($UseChinaMirror) {
    Set-UserEnv 'PUB_HOSTED_URL'          'https://pub.flutter-io.cn'
    Set-UserEnv 'FLUTTER_STORAGE_BASE_URL' 'https://storage.flutter-io.cn'
    Write-Warn2 '已启用中国大陆镜像。若后续 flutter precache 报错，请删除这两个环境变量后重试官方源。'
}

# ----------------------------------------------------------------------------
# 2. Git
# ----------------------------------------------------------------------------
Write-Step '步骤 1 / 7 —— Git'
if ($SkipGit) {
    Write-Info '已按参数跳过。'
    Add-Result 'Git' '跳过' '-SkipGit'
} elseif (Test-CommandExists 'git') {
    $gv = (& git --version) 2>&1
    Write-Ok ("已安装: " + $gv)
    Add-Result 'Git' '已具备' "$gv"
} else {
    if (Invoke-Winget 'Git.Git') {
        Write-Ok 'Git 安装完成。'
        Add-Result 'Git' '已安装' 'winget Git.Git'
    } else {
        Write-Err2 'Git 安装失败，请手动前往 https://git-scm.com/download/win 安装。'
        Add-Result 'Git' '失败' '需手动安装'
    }
}

# ----------------------------------------------------------------------------
# 3. Flutter SDK
# ----------------------------------------------------------------------------
Write-Step '步骤 2 / 7 —— Flutter SDK'
$flutterRoot = Join-Path $InstallRoot 'flutter'
$flutterBin  = Join-Path $flutterRoot 'bin'

if ($SkipFlutter) {
    Write-Info '已按参数跳过。'
    Add-Result 'Flutter SDK' '跳过' '-SkipFlutter'
} elseif (Test-Path -LiteralPath (Join-Path $flutterBin 'flutter.bat')) {
    Write-Ok ("已存在 Flutter SDK: " + $flutterRoot)
    Add-UserPath $flutterBin
    Add-Result 'Flutter SDK' '已具备' $flutterRoot
} else {
    $archiveUrl = ''
    $resolvedVersion = ''
    try {
        Write-Info '查询官方 stable 频道版本清单...'
        $relJson = Invoke-RestMethod -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json' -UseBasicParsing -TimeoutSec 120
        $target = $null
        if ($FlutterVersion -ne '') {
            $target = $relJson.releases | Where-Object { $_.version -eq $FlutterVersion } | Select-Object -First 1
            if ($null -eq $target) { Write-Warn2 ("未找到指定版本 " + $FlutterVersion + "，回退到当前 stable。") }
        }
        if ($null -eq $target) {
            $stableHash = $relJson.current_release.stable
            $target = $relJson.releases | Where-Object { $_.hash -eq $stableHash -and $_.channel -eq 'stable' } | Select-Object -First 1
        }
        if ($null -ne $target) {
            $archiveUrl = $relJson.base_url + '/' + $target.archive
            $resolvedVersion = $target.version
        }
    } catch {
        Write-Warn2 ("版本清单查询失败：" + $_.Exception.Message)
    }

    if ($archiveUrl -eq '') {
        Write-Err2 '无法解析 Flutter 下载地址。请手动前往 https://docs.flutter.dev/get-started/install/windows 下载 zip，'
        Write-Err2 ("解压到 " + $flutterRoot + " 后重新运行本脚本。")
        Add-Result 'Flutter SDK' '失败' '下载地址解析失败'
    } else {
        Write-Info ("目标版本: " + $resolvedVersion)
        $zipPath = Join-Path $script:DownloadDir ('flutter_windows_' + $resolvedVersion + '.zip')
        if (Invoke-Download -Url $archiveUrl -OutFile $zipPath) {
            Write-Info ('解压中（约 2.8 GB，需要几分钟）...')
            if (Expand-ZipTo -ZipPath $zipPath -Destination $InstallRoot) {
                if (Test-Path -LiteralPath (Join-Path $flutterBin 'flutter.bat')) {
                    Add-UserPath $flutterBin
                    Write-Ok ('Flutter SDK 安装完成: ' + $flutterRoot)
                    Add-Result 'Flutter SDK' '已安装' ($resolvedVersion + ' -> ' + $flutterRoot)
                } else {
                    Write-Err2 '解压后未找到 flutter\bin\flutter.bat，请检查压缩包完整性。'
                    Add-Result 'Flutter SDK' '失败' '解压结构异常'
                }
            } else {
                Add-Result 'Flutter SDK' '失败' '解压失败'
            }
        } else {
            Write-Err2 'Flutter SDK 下载失败（文件约 1.1 GB，请检查网络或加 -UseChinaMirror 重试）。'
            Add-Result 'Flutter SDK' '失败' '下载失败'
        }
    }
}

# ----------------------------------------------------------------------------
# 4. Visual Studio 2022 + 使用 C++ 的桌面开发
# ----------------------------------------------------------------------------
Write-Step '步骤 3 / 7 —— Visual Studio「使用 C++ 的桌面开发」工具链（Build Tools，轻量）'
Write-Warn2 '本步骤下载量约 1-3 GB，耗时 20-90 分钟，会弹出 UAC 授权窗口请点击「是」。'
Write-Warn2 '仅安装编译所需的 MSVC / Windows SDK / CMake / Ninja，不含完整 IDE（你可用 VS Code 做编辑器）。'

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vcInstalled = $false
if (Test-Path -LiteralPath $vswhere) {
    try {
        $vsPath = & $vswhere -products '*' -requires 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' -property installationPath -latest 2>$null
        if (-not [string]::IsNullOrWhiteSpace($vsPath)) {
            $vcInstalled = $true
            Write-Ok ('已检测到含 C++ 工具集的 Visual Studio / Build Tools: ' + $vsPath)
        }
    } catch { }
}

if ($SkipVisualStudio) {
    Write-Info '已按参数跳过。'
    Add-Result 'Visual Studio C++' '跳过' '-SkipVisualStudio'
} elseif ($vcInstalled) {
    Add-Result 'Visual Studio C++' '已具备' '含 VC.Tools.x86.x64'
} else {
    # 直接下载官方引导程序（微软 CDN，比 winget --override 更稳），避免 --norestart 被误判为 winget 参数
    $vsBootstrapper = Join-Path $script:DownloadDir 'vs_buildtools.exe'
    $vsUrl = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'
    if (Invoke-Download -Url $vsUrl -OutFile $vsBootstrapper) {
        $vsArgs = @(
            '--passive', '--norestart', '--wait',
            '--add', 'Microsoft.VisualStudio.Workload.NativeDesktop',
            '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
            '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621',
            '--add', 'Microsoft.VisualStudio.Component.VC.CMake.Project',
            '--includeRecommended'
        )
        Write-Info ('启动 VS Build Tools 安装（被动模式，完成后自动继续）...')
        $p = Start-Process -FilePath $vsBootstrapper -ArgumentList $vsArgs -Wait -PassThru
        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
            Write-Ok ('Visual Studio Build Tools 安装完成（退出码 ' + $p.ExitCode + '）。')
            Add-Result 'Visual Studio C++' '已安装' 'BuildTools NativeDesktop'
        } else {
            Write-Err2 ('VS Build Tools 安装退出码 ' + $p.ExitCode + '。可改用完整 Visual Studio Community 手动安装：')
            Write-Err2 '  下载 https://visualstudio.microsoft.com/zh-hans/downloads/ 的「Community 2022」'
            Write-Err2 '  勾选【使用 C++ 的桌面开发】，确认含 MSVC v143、Windows 11 SDK、C++ CMake 工具'
            Add-Result 'Visual Studio C++' '失败' ('VS Bootstrapper exit ' + $p.ExitCode)
        }
    } else {
        Write-Err2 'VS Build Tools 引导程序下载失败（网络问题）。请手动安装：'
        Write-Err2 '  1) 下载 https://visualstudio.microsoft.com/zh-hans/downloads/ 的「生成工具 for Visual Studio 2022」'
        Write-Err2 '  2) 勾选【使用 C++ 的桌面开发】工作负载，确认含 MSVC v143、Windows 11 SDK、C++ CMake 工具'
        Add-Result 'Visual Studio C++' '失败' '引导程序下载失败'
    }
}

# ----------------------------------------------------------------------------
# 5. JDK 17
# ----------------------------------------------------------------------------
Write-Step '步骤 4 / 7 —— Microsoft Build of OpenJDK 17'

function Find-Jdk17Home {
    $candidates = @()
    $roots = @(
        (Join-Path $env:ProgramFiles 'Eclipse Adoptium'),
        (Join-Path $env:ProgramFiles 'Java'),
        (Join-Path $env:ProgramFiles 'Microsoft')
    )
    foreach ($r in $roots) {
        if (Test-Path -LiteralPath $r) {
            $dirs = Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue
            foreach ($d in $dirs) {
                if (Test-Path -LiteralPath (Join-Path $d.FullName 'bin\javac.exe')) {
                    $candidates += $d.FullName
                }
            }
        }
    }
    $jdk17 = $candidates | Where-Object { $_ -match '17' } | Select-Object -First 1
    if ($null -ne $jdk17) { return $jdk17 }
    if ($candidates.Count -gt 0) { return $candidates[0] }
    return ''
}

if ($SkipJdk) {
    Write-Info '已按参数跳过。'
    Add-Result 'JDK 17' '跳过' '-SkipJdk'
} else {
    $jdkHome = Find-Jdk17Home
    if ($jdkHome -eq '') {
        # 优先 Microsoft Build of OpenJDK 17（微软 CDN，国内访问通常比 GitHub 的 Adoptium 更稳定）
        if (Invoke-Winget 'Microsoft.OpenJDK.17') {
            Start-Sleep -Seconds 3
            $jdkHome = Find-Jdk17Home
        }
    }
    if ($jdkHome -ne '') {
        Set-UserEnv 'JAVA_HOME' $jdkHome
        Add-UserPath (Join-Path $jdkHome 'bin')
        Write-Ok ('JDK 就绪: ' + $jdkHome)
        Add-Result 'JDK 17' '已就绪' $jdkHome
    } else {
        Write-Err2 'JDK 17 安装失败。请手动前往 https://learn.microsoft.com/zh-cn/java/openjdk/download 下载 Microsoft Build of OpenJDK 17 (.msi) 安装。'
        Add-Result 'JDK 17' '失败' '需手动安装'
    }
}

# ----------------------------------------------------------------------------
# 6. Android SDK
# ----------------------------------------------------------------------------
Write-Step '步骤 5 / 7 —— Android SDK (cmdline-tools / platform-tools / build-tools)'
$androidRoot     = Join-Path $InstallRoot 'Android\Sdk'
$cmdlineLatest   = Join-Path $androidRoot 'cmdline-tools\latest'
$sdkManagerBat   = Join-Path $cmdlineLatest 'bin\sdkmanager.bat'

if ($SkipAndroid) {
    Write-Info '已按参数跳过。'
    Add-Result 'Android SDK' '跳过' '-SkipAndroid'
} else {
    if (-not (Test-Path -LiteralPath $sdkManagerBat)) {
        $ctZip = Join-Path $script:DownloadDir 'android-cmdline-tools.zip'
        if (Invoke-Download -Url $CmdlineToolsUrl -OutFile $ctZip) {
            $tmpExtract = Join-Path $script:DownloadDir 'ct_extract'
            if (Test-Path -LiteralPath $tmpExtract) { Remove-Item -LiteralPath $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue }
            if (Expand-ZipTo -ZipPath $ctZip -Destination $tmpExtract) {
                $inner = Join-Path $tmpExtract 'cmdline-tools'
                if (Test-Path -LiteralPath $inner) {
                    New-Item -ItemType Directory -Path (Join-Path $androidRoot 'cmdline-tools') -Force | Out-Null
                    if (Test-Path -LiteralPath $cmdlineLatest) {
                        Remove-Item -LiteralPath $cmdlineLatest -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Move-Item -LiteralPath $inner -Destination $cmdlineLatest -Force
                    Write-Ok ('cmdline-tools 已部署: ' + $cmdlineLatest)
                } else {
                    Write-Err2 '压缩包结构异常，未找到 cmdline-tools 目录。'
                }
            }
        } else {
            Write-Err2 'cmdline-tools 下载失败。'
            Write-Err2 '请到 https://developer.android.com/studio#command-line-tools-only 复制最新下载链接，'
            Write-Err2 '然后用 -CmdlineToolsUrl "<新地址>" 重新运行本脚本。'
        }
    } else {
        Write-Ok ('已存在 cmdline-tools: ' + $cmdlineLatest)
    }

    if (Test-Path -LiteralPath $sdkManagerBat) {
        Set-UserEnv 'ANDROID_HOME'     $androidRoot
        Set-UserEnv 'ANDROID_SDK_ROOT' $androidRoot
        Add-UserPath (Join-Path $cmdlineLatest 'bin')
        Add-UserPath (Join-Path $androidRoot 'platform-tools')

        if ([string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
            Write-Err2 'JAVA_HOME 为空，sdkmanager 无法运行。请先完成 JDK 步骤。'
            Add-Result 'Android SDK' '部分失败' 'sdkmanager 需要 JAVA_HOME'
        } else {
            $pkgs = @('platform-tools', ('platforms;' + $AndroidPlatform), ('build-tools;' + $AndroidBuildTools))
            Write-Info ('安装 SDK 组件: ' + ($pkgs -join ', '))
            $sdkArgs = @(('--sdk_root=' + $androidRoot)) + $pkgs
            $p = Start-Process -FilePath $sdkManagerBat -ArgumentList $sdkArgs -NoNewWindow -Wait -PassThru
            if ($p.ExitCode -eq 0) {
                Write-Ok 'Android SDK 组件安装完成。'
                Add-Result 'Android SDK' '已安装' ($pkgs -join ', ')
            } else {
                Write-Warn2 ('sdkmanager 退出码 ' + $p.ExitCode + '，请查看上方输出。')
                Add-Result 'Android SDK' '部分失败' ('sdkmanager exit ' + $p.ExitCode)
            }

            # ---- 许可协议 ----
            if ($AutoAcceptAndroidLicenses) {
                Write-Info '正在自动接受 Android SDK 许可协议（您已通过 -AutoAcceptAndroidLicenses 表示同意）...'
                $yFile = Join-Path $script:DownloadDir 'yes.txt'
                $yLines = @()
                for ($i = 0; $i -lt 80; $i++) { $yLines += 'y' }
                Set-Content -LiteralPath $yFile -Value $yLines -Encoding ASCII
                $lp = Start-Process -FilePath $sdkManagerBat `
                                    -ArgumentList @(('--sdk_root=' + $androidRoot), '--licenses') `
                                    -NoNewWindow -Wait -PassThru -RedirectStandardInput $yFile
                if ($lp.ExitCode -eq 0) {
                    Write-Ok 'Android SDK 许可协议已接受。'
                } else {
                    Write-Warn2 '许可协议自动接受可能未完全成功，请稍后手动执行 flutter doctor --android-licenses。'
                }
            } else {
                Write-Warn2 '【需要您手动操作】许可协议未自动接受。请在本脚本结束后，新开一个终端执行：'
                Write-Warn2 '    flutter doctor --android-licenses'
                Write-Warn2 '并对每一条协议输入 y 回车（通常 5-7 条）。不接受则无法构建 apk。'
            }
        }
    } else {
        Add-Result 'Android SDK' '失败' 'cmdline-tools 未就绪'
    }
}

# ----------------------------------------------------------------------------
# 7. Flutter 配置与预缓存
# ----------------------------------------------------------------------------
Write-Step '步骤 6 / 7 —— Flutter 配置与预缓存'
$flutterBatPath = Join-Path $flutterBin 'flutter.bat'
if (Test-Path -LiteralPath $flutterBatPath) {
    try {
        if (Test-Path -LiteralPath $androidRoot) {
            Write-Info ('配置 flutter android-sdk 路径: ' + $androidRoot)
            & $flutterBatPath config --android-sdk $androidRoot 2>&1 | Out-Null
        }
        Write-Info '关闭匿名使用情况上报（可选，符合客户「完全离线」偏好）...'
        & $flutterBatPath config --no-analytics 2>&1 | Out-Null

        Write-Info '预缓存 Windows / Android 构建产物（首次约 1-2 GB，请耐心等待）...'
        & $flutterBatPath precache --windows --android 2>&1 | Out-Null
        Write-Ok 'Flutter 预缓存完成。'
        Add-Result 'Flutter 配置' '完成' 'config + precache'
    } catch {
        Write-Warn2 ('Flutter 配置步骤出现问题：' + $_.Exception.Message)
        Add-Result 'Flutter 配置' '警告' $_.Exception.Message
    }
} else {
    Write-Warn2 '未找到 flutter.bat，跳过配置步骤。'
    Add-Result 'Flutter 配置' '跳过' 'flutter 未安装'
}

# ----------------------------------------------------------------------------
# 8. 汇总
# ----------------------------------------------------------------------------
Write-Step '步骤 7 / 7 —— 安装结果汇总'
$script:Results | Format-Table -AutoSize | Out-String | Write-Host

Write-Host ''
Write-Host '------------------------------ 后续必做事项 ------------------------------' -ForegroundColor Yellow
Write-Host ' 1) 【重要】关闭当前所有终端窗口，重新打开一个新的 PowerShell。' -ForegroundColor Yellow
Write-Host '    （环境变量只对新开的进程生效）' -ForegroundColor Yellow
Write-Host ' 2) 若 Visual Studio 安装过程中提示需要重启，请重启计算机。' -ForegroundColor Yellow
if (-not $AutoAcceptAndroidLicenses) {
    Write-Host ' 3) 手动接受 Android 许可：flutter doctor --android-licenses（逐条输入 y）' -ForegroundColor Yellow
}
Write-Host ' 4) 运行验证脚本：powershell -ExecutionPolicy Bypass -File .\verify_env.ps1' -ForegroundColor Yellow
Write-Host ' 5) 把 verify_env.ps1 生成的报告文件回传给我方，我方据此确认是否可进入 M0。' -ForegroundColor Yellow
Write-Host '--------------------------------------------------------------------------' -ForegroundColor Yellow
Write-Host ''
