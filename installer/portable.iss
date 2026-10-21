; Versao PORTATIL (um unico .exe): extrai no temp, abre o app e apaga tudo ao fechar.
#ifndef Version
  #define Version "0.0.0"
#endif

[Setup]
AppId={{6D6F6F6E-6472-6F70-2D70-632D50525442}
AppName=MOONDROP PC
AppVersion={#Version}
AppPublisher=Projeto pessoal (nao oficial)
CreateAppDir=no
Uninstallable=no
DisableProgramGroupPage=yes
DisableWelcomePage=yes
DisableReadyPage=yes
DisableFinishedPage=yes
DisableDirPage=yes
OutputDir=..\dist
OutputBaseFilename=MOONDROP_PC-v{#Version}-Portable
SetupIconFile=..\app\assets\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupMutex=MoondropPcPortableSetup

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\dist\MOONDROP_PC\*"; DestDir: "{tmp}\MOONDROP_PC"; Flags: recursesubdirs ignoreversion

[Run]
Filename: "{tmp}\MOONDROP_PC\moondrop_pc.exe"; WorkingDir: "{tmp}\MOONDROP_PC"; Flags: waituntilterminated; BeforeInstall: EsconderAssistente

[Code]
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  // sem perguntas: vai direto para a extracao e abre o app
  Result := (PageID = wpWelcome) or (PageID = wpReady) or (PageID = wpFinished);
end;

procedure EsconderAssistente;
begin
  // o app ja esta abrindo: some com a janela do instalador enquanto ele roda
  WizardForm.Hide;
end;