param(
  [int]$Port = 64881,
  [string]$Device = "chrome"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

$listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listener) {
  $proc = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
  if ($proc -and ($proc.ProcessName -match "flutter|dart|chrome|msedge")) {
    Write-Host "Encerrando processo antigo na porta $Port (PID $($proc.Id), $($proc.ProcessName))..." -ForegroundColor Yellow
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
  } else {
    throw "A porta $Port esta em uso por um processo nao esperado. Libere essa porta manualmente e rode o script novamente."
  }
}

Write-Host "Iniciando Flutter web em http://localhost:$Port/#/" -ForegroundColor Green
Write-Host "Comandos durante execucao: r=hot reload | R=hot restart | q=sair" -ForegroundColor Cyan

flutter run -d $Device --web-hostname 0.0.0.0 --web-port $Port
