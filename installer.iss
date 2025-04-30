#define MyAppName "Malbrose POS"
#define MyAppVersion "1.1"
#define MyAppPublisher "Mabrose inc."
#define MyAppURL "https://derrickportfolio.vercel.app/"
#define MyAppExeName "Malbrose_POS.exe"
#define MyAppAssocName MyAppName + " File"
#define MyAppAssocExt ".myp"
#define MyAppAssocKey StringChange(MyAppAssocName, " ", "") + MyAppAssocExt
#define MyAppDataDir "{commonappdata}\Malbrose POS"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{AE9C9969-F75E-4108-BD07-696A46A2A82A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName=C:\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
; "ArchitecturesAllowed=x64compatible" specifies that Setup cannot run
; on anything but x64 and Windows 11 on Arm.
ArchitecturesAllowed=x64compatible
; "ArchitecturesInstallIn64BitMode=x64compatible" requests that the
; install be done in "64-bit mode" on x64 or Windows 11 on Arm,
; meaning it should use the native 64-bit Program Files directory and
; the 64-bit view of the registry.
ArchitecturesInstallIn64BitMode=x64compatible
ChangesAssociations=yes
DisableProgramGroupPage=yes
LicenseFile=C:\Users\batman\malbrose-flutter-app\license.txt
InfoBeforeFile=C:\Users\batman\malbrose-flutter-app\readme.txt
InfoAfterFile=C:\Users\batman\malbrose-flutter-app\getting_started.txt
; Require administrator privileges for installation
PrivilegesRequired=admin
OutputDir=C:\Users\batman\malbrose-flutter-app\installers
OutputBaseFilename=Malbrose POS
SetupIconFile=C:\Users\batman\malbrose-flutter-app\assets\malbrose.ico
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "C:\Users\batman\malbrose-flutter-app\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\batman\malbrose-flutter-app\build\windows\x64\runner\Release\connectivity_plus_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\batman\malbrose-flutter-app\build\windows\x64\runner\Release\file_selector_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\batman\malbrose-flutter-app\build\windows\x64\runner\Release\flutter_secure_storage_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\batman\malbrose-flutter-app\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\batman\malbrose-flutter-app\build\windows\x64\runner\Release\pdfium.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\batman\malbrose-flutter-app\build\windows\x64\runner\Release\permission_handler_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\batman\malbrose-flutter-app\build\windows\x64\runner\Release\printing_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\batman\malbrose-flutter-app\build\windows\x64\runner\Release\share_plus_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\batman\malbrose-flutter-app\build\windows\x64\runner\Release\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\batman\malbrose-flutter-app\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; Add VC++ Redistributables
Source: "C:\Users\batman\malbrose-flutter-app\VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "C:\Users\batman\malbrose-flutter-app\VC_redist.x86.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "C:\Users\batman\malbrose-flutter-app\copy_dlls.bat"; DestDir: "{tmp}"; Flags: deleteafterinstall
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

; Create data directories with proper permissions
[Dirs]
Name: "{app}\data"; Permissions: everyone-full
Name: "{#MyAppDataDir}"; Permissions: everyone-full
Name: "{#MyAppDataDir}\database"; Permissions: everyone-full

[Registry]
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocExt}\OpenWithProgids"; ValueType: string; ValueName: "{#MyAppAssocKey}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}"; ValueType: string; ValueName: ""; ValueData: "{#MyAppAssocName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
; Use HKLM for machine-wide settings accessible to all users
Root: HKLM; Subkey: "Software\Malbrose\POS"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Malbrose\POS"; ValueType: string; ValueName: "DataPath"; ValueData: "{#MyAppDataDir}"; Flags: uninsdeletekey

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Make sure the data directories have proper permissions for all users
Filename: "{cmd}"; Parameters: "/c icacls ""{#MyAppDataDir}"" /grant Everyone:(OI)(CI)F /T"; Flags: runhidden
Filename: "{cmd}"; Parameters: "/c icacls ""{#MyAppDataDir}\database"" /grant Everyone:(OI)(CI)F /T"; Flags: runhidden
; Install VC++ Redistributables if needed
Filename: "{tmp}\VC_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ 2015-2022 Redistributable (x64)..."; Flags: runhidden
Filename: "{tmp}\VC_redist.x86.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ 2015-2022 Redistributable (x86)..."; Flags: runhidden; Check: not Is64BitInstallMode
; Run the copy_dlls batch file if needed
Filename: "{tmp}\copy_dlls.bat"; WorkingDir: "{app}"; Flags: runhidden; StatusMsg: "Configuring application files..."
; Launch the application
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent 