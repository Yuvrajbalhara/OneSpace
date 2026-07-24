$ErrorActionPreference = 'Stop'

Write-Host 'Preparing OneSpace dependencies...'
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

Write-Host 'Building Windows release...'
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows release build failed.' }

Write-Host 'Building Android APK...'
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'Android APK build failed.' }

$releaseRoot = Join-Path $PSScriptRoot 'release'
$windowsOutput = Join-Path $releaseRoot 'windows'
$androidOutput = Join-Path $releaseRoot 'android'
New-Item -ItemType Directory -Force -Path $windowsOutput | Out-Null
New-Item -ItemType Directory -Force -Path $androidOutput | Out-Null

Copy-Item -Path (Join-Path $PSScriptRoot 'build\windows\x64\runner\Release\*') -Destination $windowsOutput -Recurse -Force
Copy-Item -Path (Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk') -Destination (Join-Path $androidOutput 'OneSpace.apk') -Force

Write-Host ''
Write-Host 'Release files are ready:'
Write-Host "Windows: $windowsOutput"
Write-Host "Android: $(Join-Path $androidOutput 'OneSpace.apk')"
Write-Host ''
Write-Host 'Distribute the entire Windows folder, not only onespace.exe.'
