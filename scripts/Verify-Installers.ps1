param([string]$OutputFolder = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (!$OutputFolder) {
    $props = [xml](Get-Content -LiteralPath (Join-Path $projectRoot 'Directory.Build.props') -Raw)
    $version = [string]$props.Project.PropertyGroup.VersionPrefix
    $suffix = [string]$props.Project.PropertyGroup.VersionSuffix
    if ($suffix) { $version += '-' + $suffix }
    $OutputFolder = Join-Path $projectRoot ('DAGITIM/' + $version)
}
$manifest = Get-Content -LiteralPath (Join-Path $OutputFolder 'PAKETLER.json') -Raw | ConvertFrom-Json
$verificationRoot = Join-Path $projectRoot ('artifacts/install-verification-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $verificationRoot | Out-Null
$results = foreach ($entry in $manifest) {
    $setup = Join-Path $OutputFolder $entry.File
    if ((Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash -ne $entry.SHA256) { throw 'Kurulum hash hatalı.' }
    $target = Join-Path $verificationRoot ([IO.Path]::GetFileNameWithoutExtension($entry.File))
    $log = $target + '.log'
    # CI/verification may never bypass the user's checkbox and Tamam consent.
    $arguments = @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/TASKS=cleandata',('/DIR="' + $target + '"'),('/LOG="' + $log + '"'))
    $process = Start-Process -FilePath $setup -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -eq 0) { throw 'Kurulum kullanıcı kabulünü atladı.' }
    if ((Get-Content -LiteralPath $log -Raw) -notmatch 'InitializeSetup returned False') { throw 'Kurulum beklenen onay kapısında durmadı.' }
    if (Test-Path -LiteralPath $target) { throw 'Kullanıcı kabulü olmadan program klasörü oluşturuldu.' }
    [pscustomobject]@{ File=$entry.File; HashVerified=$true; ConsentRequired=$true; SilentExitCode=$process.ExitCode }
}
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $verificationRoot 'RESULTS.json') -Encoding utf8
$results | Format-Table
Write-Output 'Tam kurulum/güncelleme/kaldırma kabulü etkileşimli bir Windows oturumunda ayrıca yapılmalıdır.'