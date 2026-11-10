# Ejecuta SIGFV en un teléfono Android conectado por USB.
# Uso:  powershell -ExecutionPolicy Bypass -File .\run_android.ps1
$ErrorActionPreference = 'Stop'
$flutter = 'C:\Users\Usuario\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) {
    throw "No se encontró Flutter en $flutter"
}

Push-Location $PSScriptRoot
try {
    & $flutter devices
    & $flutter run
} finally {
    Pop-Location
}
