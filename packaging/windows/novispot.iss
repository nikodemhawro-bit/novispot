#define MyAppName "Novispot"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppExeName "novispot.exe"

[Setup]
AppId={{A83D7E51-2C49-4B1F-9F73-6E4B2C8A105D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Novispot
DefaultDirName={localappdata}\Programs\Novispot
DefaultGroupName=Novispot
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
OutputBaseFilename=Novispot-Setup-{#MyAppVersion}
OutputDir=..\..\dist
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\novispot.exe
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
DisableProgramGroupPage=yes

[Tasks]
Name: "desktopicon"; Description: "Utwórz skrót na pulpicie"; GroupDescription: "Dodatkowe skróty:"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Novispot"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\Novispot"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Uruchom Novispot"; Flags: postinstall nowait skipifsilent
