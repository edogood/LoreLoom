[CmdletBinding()]
param(
  [switch]$Background,
  [switch]$ForceInstall,
  [switch]$ForceSeed,
  [switch]$OpenBrowser,
  [ValidateSet("Stable", "Dev")]
  [string]$Mode = "Stable",
  [switch]$SkipBuild,
  [switch]$ForceBuild,
  [int]$Port = 3000
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$webRoot = Join-Path $projectRoot "apps\web"
$baseUrl = "http://localhost:$Port"
$dashboardUrl = "$baseUrl/dashboard"
$dbPath = Join-Path $projectRoot "data\loreloom.db"
$nodeModulesPath = Join-Path $projectRoot "node_modules"
$nextCachePath = Join-Path $projectRoot "apps\web\.next"
$nextBuildIdPath = Join-Path $nextCachePath "BUILD_ID"
$stdoutPath = Join-Path $projectRoot "dev-server.out.log"
$stderrPath = Join-Path $projectRoot "dev-server.err.log"
$pidPath = Join-Path $projectRoot "dev-server.pid"

function Test-Url {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Url
  )

  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 2
    return $response.StatusCode -ge 200 -and $response.StatusCode -lt 500
  } catch {
    return $false
  }
}

function Test-PortOpen {
  param(
    [Parameter(Mandatory = $true)]
    [int]$PortNumber
  )

  $client = New-Object System.Net.Sockets.TcpClient

  try {
    $async = $client.BeginConnect("127.0.0.1", $PortNumber, $null, $null)
    if (-not $async.AsyncWaitHandle.WaitOne(800)) {
      return $false
    }

    $client.EndConnect($async)
    return $true
  } catch {
    return $false
  } finally {
    $client.Dispose()
  }
}

function Get-NodeMajorVersion {
  $versionText = (& node -v).Trim()

  if ($versionText -match "^v(?<major>\d+)") {
    return [int]$Matches["major"]
  }

  throw "Unrecognized Node version: $versionText"
}

function Ensure-Command {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name was not found in PATH."
  }
}

function Ensure-Dependencies {
  if ($ForceInstall -or -not (Test-Path $nodeModulesPath)) {
    Write-Host "Installing dependencies..." -ForegroundColor Cyan
    npm install
    if ($LASTEXITCODE -ne 0) {
      throw "npm install failed."
    }
  }
}

function Ensure-Database {
  if ($ForceSeed -or -not (Test-Path $dbPath) -or (Get-Item $dbPath).Length -eq 0) {
    Write-Host "Seeding local database..." -ForegroundColor Cyan
    npm run db:seed
    if ($LASTEXITCODE -ne 0) {
      throw "npm run db:seed failed."
    }
  }
}

function Reset-NextCache {
  if (Test-Path $nextCachePath) {
    Write-Host "Clearing Next.js cache..." -ForegroundColor DarkCyan
    Remove-Item -LiteralPath $nextCachePath -Recurse -Force
  }
}

function Ensure-Build {
  if ($SkipBuild) {
    return
  }

  if (-not $ForceBuild -and (Test-Path $nextBuildIdPath)) {
    Write-Host "Using existing Next.js production build." -ForegroundColor DarkCyan
    return
  }

  Write-Host "Building app for stable local run..." -ForegroundColor Cyan
  Push-Location $webRoot
  npm run build
  $exitCode = $LASTEXITCODE
  Pop-Location
  if ($exitCode -ne 0) {
    throw "npm run build failed."
  }
}

function Stop-TrackedServer {
  if (-not (Test-Path $pidPath)) {
    return
  }

  $trackedPid = Get-Content -Path $pidPath -ErrorAction SilentlyContinue
  if (-not $trackedPid) {
    return
  }

  try {
    Stop-Process -Id $trackedPid -Force -ErrorAction SilentlyContinue
  } catch {
  }

  Start-Sleep -Milliseconds 800
}

function Get-LaunchCommand {
  if ($Mode -eq "Dev") {
    return "set PORT=$Port && npm run dev"
  }

  return "set PORT=$Port && npm run start -- --port $Port"
}

function Repair-NextServerChunks {
  if ($Mode -ne "Stable") {
    return
  }

  $serverRoot = Join-Path $nextCachePath "server"
  $chunkRoot = Join-Path $serverRoot "chunks"

  if (-not (Test-Path $chunkRoot)) {
    return
  }

  Get-ChildItem -LiteralPath $chunkRoot -Filter "*.js" | ForEach-Object {
    $target = Join-Path $serverRoot $_.Name
    if (-not (Test-Path $target)) {
      Copy-Item -LiteralPath $_.FullName -Destination $target -Force
    }
  }
}

function Start-BrowserDeferred {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Url
  )

  Start-Job -ScriptBlock {
    param($BrowserUrl)

    for ($attempt = 0; $attempt -lt 24; $attempt += 1) {
      try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $BrowserUrl -TimeoutSec 2
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
          Start-Process $BrowserUrl
          return
        }
      } catch {
      }

      Start-Sleep -Seconds 2
    }
  } -ArgumentList $Url | Out-Null
}

Set-Location $projectRoot

Ensure-Command -Name "node"
Ensure-Command -Name "npm"

$nodeMajor = Get-NodeMajorVersion
if ($nodeMajor -lt 22) {
  throw "Node.js $nodeMajor is not supported. Use Node 22 or newer."
}

if (Test-Url -Url $dashboardUrl) {
  Write-Host "Loreloom is already running on $baseUrl" -ForegroundColor Yellow
  Write-Host "Open: $dashboardUrl"

  if ($OpenBrowser) {
    Start-Process $dashboardUrl
  }

  exit 0
}

Ensure-Dependencies
Ensure-Database
Stop-TrackedServer

if (Test-Url -Url $dashboardUrl) {
  Write-Host "Loreloom is already running on $baseUrl" -ForegroundColor Yellow
  Write-Host "Open: $dashboardUrl"

  if ($OpenBrowser) {
    Start-Process $dashboardUrl
  }

  exit 0
}

if (Test-PortOpen -PortNumber $Port) {
  throw "Port $Port is already in use by another process. Use -Port to select a different port or stop the existing listener."
}

if ($Mode -eq "Dev") {
  Reset-NextCache
} else {
  Ensure-Build
  Repair-NextServerChunks
}

if ($Background) {
  $backgroundCommand = "$(Get-LaunchCommand) 1>>`"$stdoutPath`" 2>>`"$stderrPath`""
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = "C:\WINDOWS\System32\cmd.exe"
  $startInfo.Arguments = "/d /s /c `"$backgroundCommand`""
  $startInfo.WorkingDirectory = $webRoot
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $false
  $startInfo.RedirectStandardError = $false

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  $started = $process.Start()

  if (-not $started) {
    throw "Failed to start the background dev server."
  }

  Set-Content -Path $pidPath -Value $process.Id

  Write-Host "Loreloom started in background." -ForegroundColor Green
  Write-Host "PID: $($process.Id)"
  Write-Host "Open: $dashboardUrl"
  Write-Host "Logs: $stdoutPath"

  if ($OpenBrowser) {
    Start-BrowserDeferred -Url $dashboardUrl
  }

  exit 0
}

Write-Host "Starting Loreloom $($Mode.ToLowerInvariant()) server..." -ForegroundColor Green
Write-Host "Open: $dashboardUrl"
Write-Host "Press Ctrl+C to stop the server."

if ($OpenBrowser) {
  Start-BrowserDeferred -Url $dashboardUrl
}
if ($Mode -eq "Dev") {
  Push-Location $webRoot
  $env:PORT = "$Port"
  npm run dev
  $exitCode = $LASTEXITCODE
  Pop-Location
  exit $exitCode
}

Push-Location $webRoot
npm run start -- --port $Port
$exitCode = $LASTEXITCODE
Pop-Location
exit $exitCode
