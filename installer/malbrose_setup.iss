; Inno Setup Script for Malbrose POS Flutter App
; This script includes Visual C++ Redistributable packages to prevent MSVCP140.dll errors

#define MyAppName "Malbrose POS"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Your Company Name"
#define MyAppURL "https://yourwebsite.com"
#define MyAppExeName "my_flutter_app.exe"

[Setup]
; Basic Setup Information
AppId={{MALBROSE-POS-APP-UNIQUE-ID}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Compression settings
Compression=lzma
SolidCompression=yes
; Output directory and filename for the installer
OutputDir=output
OutputBaseFilename=malbrose_pos_setup
; Installer graphics and branding
; Uncomment and set path to your icon if available
;SetupIconFile=path\to\your\app\icon.ico
; Installer requires admin rights to install VC++ redistributables
PrivilegesRequired=admin
; Minimum Windows version - Windows 7 SP1
MinVersion=6.1.7601

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Your Flutter app files
Source: "C:\Users\bruce wayne\malbrose-flutter-app\build\windows\x64\runner\Release\my_flutter_app.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\bruce wayne\malbrose-flutter-app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "C:\Users\bruce wayne\malbrose-flutter-app\windows\runner\dll_loader.h"; DestDir: "{app}\include"; Flags: ignoreversion

; Visual C++ Redistributable packages
Source: "C:\Users\bruce wayne\malbrose-flutter-app\installer\VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "C:\Users\bruce wayne\malbrose-flutter-app\installer\VC_redist.x86.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Code]
function IsWin7OrLater(): Boolean;
begin
  Result := CheckWindowsVersion(6, 1);
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  
  // Check for specific Windows versions and show warnings if needed
  if (GetWindowsVersion < $06030000) then begin  // Less than Windows 8.1
    MsgBox('This application works best with Windows 8.1 or later. Some features may not work correctly on your system.', mbInformation, MB_OK);
  end;
end;

[Run]
; Install Visual C++ Redistributable Packages
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ Redistributable (x64)..."; Flags: waituntilterminated
Filename: "{tmp}\vc_redist.x86.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ Redistributable (x86)..."; Flags: waituntilterminated

; Launch the application
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent