; Instalador do MOONDROP PC (Inno Setup). Gerado/compilado por tools\release.ps1
#ifndef Version
  #define Version "0.0.0"
#endif

[Setup]
AppId={{6D6F6F6E-6472-6F70-2D70-632D31323334}
AppName=MOONDROP PC
AppVersion={#Version}
AppPublisher=Projeto pessoal (nao oficial)
DefaultDirName={autopf}\MOONDROP PC
DefaultGroupName=MOONDROP PC
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=MOONDROP_PC-v{#Version}-Setup
SetupIconFile=..\app\assets\app_icon.ico
UninstallDisplayIcon={app}\moondrop_pc.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar um atalho na &Area de Trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked
Name: "startup"; Description: "Iniciar com o &Windows"; GroupDescription: "Opcoes:"; Flags: unchecked

[Files]
Source: "..\dist\MOONDROP_PC\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\MOONDROP PC"; Filename: "{app}\moondrop_pc.exe"
Name: "{autodesktop}\MOONDROP PC"; Filename: "{app}\moondrop_pc.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "MOONDROP PC"; ValueData: """{app}\moondrop_pc.exe"""; Tasks: startup; Flags: uninsdeletevalue

[Run]
Filename: "{app}\moondrop_pc.exe"; Description: "Abrir o MOONDROP PC"; Flags: nowait postinstall skipifsilent