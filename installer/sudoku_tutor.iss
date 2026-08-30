; ============================================================
;  数独学堂 SudokuTutor — Windows 安装包脚本
;  任务编号：T-PKG-01 / doc 07 §6 P0-PKG-01~04
;  依赖产物：dist/SudokuTutor-windows-x64/  （由 scripts/build_release.ps1 步骤 1-2 生成）
;  编译器  ：Inno Setup 6（ISCC.exe），未签名——首次安装会触发 SmartScreen，详见
;            docs/10-T-PKG01-打包说明.md §3。
; ============================================================

#define MyAppName    "SudokuTutor 数独学堂"
#define MyAppNameEn  "SudokuTutor"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "sudututor.app"
#define MyAppCopyright "Copyright (C) 2026 sudututor.app"
#define MyAppExeName "sudoku_tutor.exe"

[Setup]
; 注意：AppId 不要随便改——一旦改了相当于换了应用，老用户的升级路径会断。
AppId={{B5E2C0F0-9D2C-4F2E-9A22-7C2E11F0A001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://sudututor.app
AppSupportURL=https://sudututor.app
AppUpdatesURL=https://sudututor.app
AppCopyright={#MyAppCopyright}
DefaultDirName={autopf}\SudokuTutor
DisableProgramGroupPage=yes
DefaultGroupName={#MyAppName}
; 输出到项目根 dist/，与 build_release.ps1 产物路径统一
OutputDir=..\dist
OutputBaseFilename=Setup-SudokuTutor-{#MyAppVersion}
SetupIconFile=..\app\assets\images\icon_placeholder.ico
Compression=lzma2/ultra64
SolidCompression=yes
; 仅允许 64 位 Windows（Win10 1809 x64 及以上）
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} 安装程序
VersionInfoProductName={#MyAppNameEn}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
; 安装过程中的提示语本地化
WelcomeLabel2=欢迎使用 [name/ver]。本程序将引导您完成安装。%n%n应用名：《数独学堂 SudokuTutor》%n发布者：{#MyAppPublisher}%n%n安装前请关闭已运行的 {#MyAppExeName}。

[Files]
; 打包 dist/SudokuTutor-windows-x64/ 整个目录（含 sudoku_tutor.exe + data/ + 必要 DLL）
; 该目录由 scripts/build_release.ps1 在执行 `flutter build windows --release` 后复制生成
Source: "..\dist\SudokuTutor-windows-x64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; ⚠️ 不要在此节放置"未使用"的源文件，否则 ISCC 编译期报"File not found"。

[Icons]
; 桌面快捷方式（可选，由 Tasks 控制）
Name: "{autodesktop}\数独学堂 SudokuTutor"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; IconIndex: 0; Tasks: desktopicon
; 开始菜单快捷方式（默认勾选）
Name: "{group}\数独学堂 SudokuTutor"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; IconIndex: 0; Tasks: startmenu
Name: "{group}\卸载 数独学堂 SudokuTutor"; Filename: "{uninstallexe}"; Tasks: startmenu

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式(&D)"; GroupDescription: "附加任务："; Flags: unchecked
Name: "startmenu";  Description: "创建开始菜单快捷方式(&S)"; GroupDescription: "附加任务："; Flags: checkedonce

[Dirs]
; 用户存档目录（首次安装创建，便于卸载时一并清理）
Name: "{userappdata}\SudokuTutor"; Permissions: users-modify

[Run]
; 安装完成后勾选"启动"才执行
Filename: "{app}\{#MyAppExeName}"; Description: "启动 数独学堂"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; 卸载时清理用户存档目录（仅当用户勾选）
Type: filesandordirs; Name: "{userappdata}\SudokuTutor"

; ============================================================
; ⚠️ SmartScreen 提示说明（给维护者）：
;   当前 Setup.exe 未签名（无 EV/OV 代码签名证书），首次安装时
;   Windows Defender SmartScreen 会显示"Windows 已保护你的电脑"提示，
;   用户需点击"更多信息 → 仍要运行"才能继续。详细处理方案见
;   docs/10-T-PKG01-打包说明.md §3（含分发/签名/用户告知三种路径）。
; ============================================================