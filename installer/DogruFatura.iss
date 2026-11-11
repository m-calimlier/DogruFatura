#ifndef AppVersion
 #define AppVersion "1.2.0"
#endif
#ifndef PayloadDir
 #define PayloadDir "..\dist\payload"
#endif
#define DataFolderName "DoğruFatura"
[Setup]
AppId={{2D22EB36-5AA7-4AD9-9814-DB03D1DFBFD3}
AppName=DoğruFatura
AppVersion={#AppVersion}
VersionInfoVersion={#AppVersion}.0
AppPublisher=Murat ÇALIMLIER
AppPublisherURL=https://github.com/m-calimlier/DogruFatura
DefaultDirName={localappdata}\Programs\DoğruFatura
DefaultGroupName=DoğruFatura
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
DisableWelcomePage=no
UsePreviousTasks=no
OutputDir=..\dist\installer
OutputBaseFilename=DogruFatura-Kurulum-{#AppVersion}
SetupIconFile=..\DogruFatura.Wpf\Assets\AppIcon.ico
UninstallDisplayIcon={app}\DogruFatura.exe
WizardStyle=modern dark polar includetitlebar hidebevels
WizardBackColor=#10263d
WizardSizePercent=115,115
WizardImageFile=Assets\setup-sidebar.png
WizardSmallImageFile=Assets\setup-mark.png
WizardImageBackColor=#10263d
WizardSmallImageBackColor=#10263d
WizardImageStretch=yes
ShowLanguageDialog=no
#ifdef FastBuild
Compression=zip/1
SolidCompression=no
#else
Compression=lzma2
SolidCompression=yes
#endif
CloseApplications=yes
CloseApplicationsFilter=DogruFatura.exe
RestartApplications=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
[Tasks]
Name: "desktopicon"; Description: "Masaüstü kısayolu oluştur"; GroupDescription: "Kısayollar:"
[Files]
; Payload must be freshly published application binaries, never a user workspace.
Source: "{#PayloadDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "Veri\*,Veriler\*,Yedekler\*,Ciktilar\*,Çıktılar\*,PDF\*,Loglar\*,InitialData\*,distribution.profile,*.pdb,*.log"
#ifdef PersonalSeedDir
[Files]
Source: "{#PersonalSeedDir}\*"; DestDir: "{app}\InitialData"; Flags: ignoreversion recursesubdirs createallsubdirs
#endif
[Icons]
Name: "{userprograms}\DoğruFatura"; Filename: "{app}\DogruFatura.exe"
Name: "{userprograms}\DoğruFatura Kaldır"; Filename: "{uninstallexe}"
Name: "{userdesktop}\DoğruFatura"; Filename: "{app}\DogruFatura.exe"; Tasks: desktopicon
[InstallDelete]
Type: files; Name: "{app}\distribution.profile"
#ifndef PersonalSeedDir
Type: filesandordirs; Name: "{app}\InitialData"
#endif
[Run]
Filename: "{app}\DogruFatura.exe"; Description: "DoğruFatura programını aç"; Flags: nowait postinstall skipifsilent
[Messages]
SetupWindowTitle=DoğruFatura · Kurulum
WelcomeLabel1=DoğruFatura programına hoş geldiniz
WelcomeLabel2=Tüm kayıtlar, ayarlar, belgeler, arşivler ve yedekler masaüstündeki "DoğruFatura" klasöründe tutulur.%n%nNormal kurulum mevcut verileri korur. Temiz kurulum seçeneği programın veri alt klasörlerini siler ve ayrıca onay gerektirir.%n%nSürüm {#AppVersion} · Windows x64
FinishedHeadingLabel=DoğruFatura kullanıma hazır
FinishedLabel=Kurulum tamamlandı.%n%nProgramı Başlat menüsünden veya masaüstü kısayolundan açabilirsiniz.%n%nCreated by Murat ÇALIMLIER
#include "CommonWizard.iss"