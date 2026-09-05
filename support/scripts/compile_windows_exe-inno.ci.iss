; CI variant of compile_windows_exe-inno.iss.
;
; Produces a plain unsigned, per-user installer for GitHub Actions. No code
; signing, no MSIX helper, no hardcoded dev-machine paths.
;
; Run with:
;   ISCC.exe /DStagingDir=<dir with doorstep.exe + dlls + data + logo.ico> \
;            /DOutputDir=<dir for the setup exe> \
;            /DMyAppVersion=<version from pubspec.yaml> \
;            compile_windows_exe-inno.ci.iss
;
; The version comes from pubspec.yaml at build time so it cannot drift from
; the app (the packaging CI check compares the non-CI script only).

#ifndef StagingDir
  #error "StagingDir must be defined (iscc /DStagingDir=...)"
#endif
#ifndef OutputDir
  #error "OutputDir must be defined (iscc /DOutputDir=...)"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppName "Doorstep"
#define MyAppPublisher "cydercoder"
#define MyAppURL "https://github.com/javex-12/Doorstep"
#define MyAppExeName "doorstep.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
AppId={{00809252-FEC6-448E-83B4-E7F55AE7E47D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#OutputDir}
OutputBaseFilename=Doorstep-{#MyAppVersion}-windows-x86-64-setup
SetupIconFile={#StagingDir}\logo.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#StagingDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
#if FileExists(AddBackslash(StagingDir) + MyAppExeName + ".manifest")
Source: "{#StagingDir}\{#MyAppExeName}.manifest"; DestDir: "{app}"; Flags: ignoreversion
#endif
Source: "{#StagingDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StagingDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}";
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent