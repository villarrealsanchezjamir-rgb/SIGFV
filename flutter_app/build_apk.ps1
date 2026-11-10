# Genera la APK release de SIGFV (Flutter).
# Uso:  powershell -ExecutionPolicy Bypass -File .\build_apk.ps1
$ErrorActionPreference = 'Stop'
$flutter = 'C:\Users\Usuario\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) {
    throw "No se encontró Flutter en $flutter"
}

Push-Location $PSScriptRoot
try {
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get falló' }

    & $flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build apk falló' }

    $apk = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
    if (Test-Path $apk) {
        Write-Host ""
        Write-Host "APK lista: $apk" -ForegroundColor Green
        Write-Host ("Tamaño: {0:N1} MB" -f ((Get-Item $apk).Length / 1MB))
    } else {
        throw 'No se generó la APK'
    }
} finally {
    Pop-Location
}
