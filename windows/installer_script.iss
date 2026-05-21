; ═══════════════════════════════════════════════════════════
; ROTTY MUSIC — INNO SETUP INSTALLER SCRIPT
; ═══════════════════════════════════════════════════════════

[Setup]
AppName=Rotty Music
AppVersion=1.0.1
AppPublisher=Rotty Music
DefaultDirName={autopf}\Rotty Music
DefaultGroupName=Rotty Music
UninstallDisplayIcon={app}\rotty_music.exe
Compression=lzma2
SolidCompression=yes
OutputDir=..\website
OutputBaseFilename=rotty-music-windows-setup
SetupIconFile=runner\resources\app_icon.ico
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\rotty_music.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Rotty Music"; Filename: "{app}\rotty_music.exe"
Name: "{autodesktop}\Rotty Music"; Filename: "{app}\rotty_music.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\rotty_music.exe"; Description: "{cm:LaunchProgram,Rotty Music}"; Flags: nowait postinstall skipifsilent
