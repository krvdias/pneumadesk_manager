; =============================================================================
; PneumaDesk Manager Inno Setup Installer Script
; Version: 1.0.0
; =============================================================================

#define MyAppName "PnumaDesk Manager"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Krv Softwares"
#define MyAppExeName "pnumadesk_manager.exe"
#define MyAppDescription "PnumaDesk Database and Connected Systems Management Console"
#define SourceDir "build\windows\x64\runner\Release"
#define OutputDir "installer"

[Setup]
AppId={{C78E4F1B-943D-4D3B-A9EF-451BE2A0D819}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://krvsoftwares.com
AppSupportURL=mailto:vishan.dias.official@gmail.com
AppCopyright=Copyright (C) 2026 Krv Softwares
VersionInfoVersion={#MyAppVersion}
VersionInfoProductName={#MyAppName}
VersionInfoDescription={#MyAppDescription}

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

OutputDir={#OutputDir}
OutputBaseFilename=PnumaDesk_Manager_Setup_v{#MyAppVersion}

SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
WizardStyle=modern

Compression=lzma2
SolidCompression=yes

PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

AllowNoIcons=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
; Main Application Executable and Dependencies
Source: "{#SourceDir}\{#MyAppExeName}";                          DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.dll";                                  DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\native_assets.json";                       DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SourceDir}\data\*";                                   DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: ".env";                                                  DestDir: "{app}"; Flags: ignoreversion

; Prerequisites (Visual C++ 2015-2022 Redistributable)
Source: "scripts\vc_redist.x64.exe";                             DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#MyAppName}";            Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"
Name: "{group}\Uninstall {#MyAppName}";  Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";      Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"; Tasks: desktopicon

[Run]
; 1. Install Microsoft Visual C++ 2015-2022 Redistributable (x64) automatically if not available on the computer
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /passive /norestart"; Check: VCRedistNeedsInstall; Flags: waituntilterminated; StatusMsg: "Checking and installing Microsoft Visual C++ Redistributable (x64)..."

; 2. Launch App Option
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
// Check if Visual C++ 2015-2022 Redistributable (x64) is already installed
function VCRedistNeedsInstall: Boolean;
var
  Installed: Cardinal;
begin
  Result := True;
  if RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed) then
  begin
    if Installed = 1 then
      Result := False;
  end;
end;
