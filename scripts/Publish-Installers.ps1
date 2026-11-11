param([string]$CompilerPath = '', [string]$DataRoot = '', [string]$OutputFolder = '', [string]$PayloadFolder = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildProps = [xml](Get-Content -LiteralPath (Join-Path $projectRoot 'Directory.Build.props') -Raw)
$version = [string]$buildProps.Project.PropertyGroup.VersionPrefix
$suffix = [string]$buildProps.Project.PropertyGroup.VersionSuffix
if (!$version) { throw 'Directory.Build.props sürümü okunamadı.' }
if ($suffix) { $version += '-' + $suffix }
if (!$DataRoot) { $DataRoot = Join-Path ([Environment]::GetFolderPath('Desktop')) 'DoğruFatura' }
if (Get-Process DogruFatura -ErrorAction SilentlyContinue) { throw 'Tutarlı kişisel paket için önce programı kapatın.' }
if (!$OutputFolder) { $OutputFolder = Join-Path $projectRoot ('DAGITIM/' + $version) }
$OutputFolder = [IO.Path]::GetFullPath($OutputFolder)
$stageRoot = Join-Path $projectRoot ('artifacts/installers-' + [Guid]::NewGuid().ToString('N'))
$payload = if ($PayloadFolder) { [IO.Path]::GetFullPath($PayloadFolder) } else { Join-Path $stageRoot 'App' }
$seedFolder = Join-Path $stageRoot 'Seed'
New-Item -ItemType Directory -Force -Path $payload,$seedFolder,$OutputFolder | Out-Null
$seedData = Join-Path $seedFolder 'Veri'
New-Item -ItemType Directory -Force -Path $seedData | Out-Null
$schoolsDocument = Get-Content -LiteralPath (Join-Path $DataRoot 'Veri/Okullar.json') -Raw | ConvertFrom-Json
if ($schoolsDocument.DataType -ne 'schools' -or !$schoolsDocument.Data) { throw 'Okul dosyası geçersiz veya boş.' }
# Personal snapshot is explicitly separate from the common application payload.
$sourceFiles = @()
foreach ($name in 'Okullar.json','AktifFaturalar.json','YetkiliProfili.json','IslemArsivi.json','DenetimKaydi.jsonl','IslemJournal.jsonl','GorunumTercihleri.json') {
  $source = Join-Path $DataRoot ('Veri/' + $name)
  if (Test-Path -LiteralPath $source) { $sourceFiles += Get-Item -LiteralPath $source }
}
foreach ($folder in 'Aktif Çıktılar','Arşivlenenler') {
  $sourceFolder = Join-Path $DataRoot $folder
  if (Test-Path -LiteralPath $sourceFolder) { $sourceFiles += @(Get-ChildItem -LiteralPath $sourceFolder -File -Filter '*.pdf') }
}
$sourceHashes = @{}
foreach ($file in $sourceFiles) {
  $relative = [IO.Path]::GetRelativePath($DataRoot,$file.FullName)
  $destination = Join-Path $seedFolder $relative
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
  $sourceHashes[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  Copy-Item -LiteralPath $file.FullName -Destination $destination
  if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $sourceHashes[$file.FullName]) { throw 'Kişisel paket kopyalanırken veri değişti.' }
}
foreach ($file in $sourceFiles) { if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne $sourceHashes[$file.FullName]) { throw 'Kişisel paket hazırlanırken kaynak veri değişti.' } }
$seedManifest = @{}
Get-ChildItem -LiteralPath $seedFolder -Recurse -File | ForEach-Object { $seedManifest[[IO.Path]::GetRelativePath($seedFolder,$_.FullName).Replace('\','/')] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
$seedManifest | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $seedFolder 'Manifest.json') -Encoding utf8
if (!$PayloadFolder) {
  & dotnet publish (Join-Path $projectRoot 'DogruFatura.Wpf/DogruFatura.Wpf.csproj') -c Release -r win-x64 --self-contained true -o $payload -p:CleanDistribution=true -p:PublishSingleFile=false -p:DebugType=None -p:DebugSymbols=false
  if ($LASTEXITCODE -ne 0) { throw 'Publish başarısız.' }
}
[void][Reflection.Assembly]::LoadFrom((Join-Path $payload 'DogruFatura.Core.dll'))
[DogruFatura.Core.Services.InitialUserDataService]::ValidateBundle($seedFolder)
$archiveDoc = Get-Content -LiteralPath (Join-Path $seedData 'IslemArsivi.json') -Raw | ConvertFrom-Json
$activeDoc = Get-Content -LiteralPath (Join-Path $seedData 'AktifFaturalar.json') -Raw | ConvertFrom-Json
$signatureDoc = Get-Content -LiteralPath (Join-Path $seedData 'YetkiliProfili.json') -Raw | ConvertFrom-Json
foreach ($required in 'DogruFatura.exe','DogruFatura.Core.dll','coreclr.dll','PresentationFramework.dll') { if (!(Test-Path (Join-Path $payload $required))) { throw "Eksik dosya: $required" } }
if (Test-Path (Join-Path $payload 'InitialData')) { throw 'Ortak yayın klasöründe başlangıç verisi olmamalı.' }
if (!$CompilerPath) { $CompilerPath = @("${env:ProgramFiles(x86)}/Inno Setup 6/ISCC.exe", "$env:LOCALAPPDATA/Programs/Inno Setup 6/ISCC.exe") | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1 }
if (!$CompilerPath) { throw 'Inno Setup 6.6+ bulunamadı; -CompilerPath belirtin.' }
$variants = @(
  @{ Code='TAM_VERILI_KISISEL'; Title='Tam Verili - Kişisel Kurulum'; Personal='1'; Short='KİŞİSEL KURULUM'; Body='Okullar, imzacılar, faturalar ve PDF arşivi dahildir. Mevcut kayıtlarınız korunur.' },
  @{ Code='TEMIZ_VERISIZ_DAGITIM'; Title='Temiz Verisiz - Dağıtım Kurulumu'; Personal='0'; Short='TEMİZ DAĞITIM KURULUMU'; Body='Ayrı ve boş bir veri alanıyla başlar. İlk kullanımda kurum ve imzacıları tanımlayın.' }
)
$manifest = @()
foreach ($variant in $variants) {
  $target = Join-Path $OutputFolder ('DogruFatura_' + $version + '_' + $variant.Code + '_x64_Setup.exe')
  $compileArgs = @('/Qp', "/DAppVersion=$version", "/DPayloadDir=$payload", "/O$OutputFolder", ('/F' + [IO.Path]::GetFileNameWithoutExtension($target)))
  if ($variant.Personal -eq '1') { $compileArgs += "/DPersonalSeedDir=$seedFolder" }
  & $CompilerPath @compileArgs (Join-Path $projectRoot 'installer/DogruFatura.iss')
  if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $target)) { throw 'Inno Setup başarısız.' }
  $personal = $variant.Personal -eq '1'
  $manifest += [pscustomobject]@{File=(Split-Path $target -Leaf);Title=$variant.Title;SHA256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash;Bytes=(Get-Item -LiteralPath $target).Length;Personal=$personal;Schools=if($personal){$schoolsDocument.Data.Count}else{0};Invoices=if($personal){@($activeDoc.Data).Count}else{0};Archives=if($personal){@($archiveDoc.Data).Count}else{0};ArchivedInvoices=if($personal){($archiveDoc.Data | ForEach-Object { $_.Invoices.Count } | Measure-Object -Sum).Sum}else{0};PrivateSignatures=if($personal){![string]::IsNullOrEmpty($signatureDoc.Data.RealizationOfficerName)}else{$false};Signed=$false}
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputFolder 'PAKETLER.json') -Encoding utf8
$manifest | ForEach-Object { $_.SHA256 + '  ' + $_.File } | Set-Content -LiteralPath (Join-Path $OutputFolder 'SHA256.txt') -Encoding utf8
@'
TAM_VERILI_KISISEL: Okullar, imzacılar, aktif faturalar, işlem arşivi, ayarlar, işlem geçmişi ve PDF belgeleri dahildir. Kişisel kullanım içindir.
TEMIZ_VERISIZ_DAGITIM: Başkasına göndermek içindir. İlk kurulumda okul, fatura, arşiv ve imza kaydı bulunmaz.
İki paket de Masaüstü/DoğruFatura ana klasörünü kullanır. Kişisel paket özel başlangıç verileri içerir; paylaşım paketi kişisel veri içermez.
Normal kurulum mevcut verileri korur. Temiz kurulum ayrıca seçilir ve açık onaydan sonra eski kayıtları siler.
SÜRÜM: Kurulum dosyasının adında belirtilen program sürümü kurulur.
Windows 10/11 x64; .NET/Excel/Visual Studio gerekmez. Kurulum geçerli kullanıcı hesabına yapılır.
Paketler dijital olarak imzalı değildir; Windows yayıncı uyarısı gösterebilir.
'@ | Set-Content -LiteralPath (Join-Path $OutputFolder 'HANGI_KURULUM.txt') -Encoding utf8
$manifest | Format-Table File,Schools,Bytes
Write-Output "Payload: $payload"
Write-Output "Output: $OutputFolder"
