$ErrorActionPreference = 'Stop'

# Project paths
$projectRoot = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path $projectRoot 'logs'
$launcherLogPath = Join-Path $logDirectory 'launcher.log'

# Ensure log directory exists
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

# Find npm
$npmCommand = (Get-Command npm.cmd -ErrorAction Stop).Source

function Write-LauncherLog {
    param([Parameter(Mandatory)][string]$Message)

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $launcherLogPath -Value "$timestamp $Message"
}

function Test-PortListening {
    param([Parameter(Mandatory)][ValidateRange(1, 65535)][int]$Port)

    try {
        return [bool](Get-NetTCPConnection `
            -State Listen `
            -LocalPort $Port `
            -ErrorAction Stop |
            Select-Object -First 1)
    }
    catch {
        return $false
    }
}

function Start-Frontend {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][ValidateRange(1, 65535)][int]$Port
    )

    # Validate project directory
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        $message = "$Name directory not found: $Directory"
        Write-LauncherLog "ERROR: $message"
        throw $message
    }

    # Skip if the port is already occupied by a listening process
    if (Test-PortListening -Port $Port) {
        $message = "$Name is already running on http://localhost:$Port"
        Write-Output $message
        Write-LauncherLog "$Name already running on port $Port"
        return
    }

    $logPath = Join-Path $logDirectory "$Name.log"
    $errorLogPath = Join-Path $logDirectory "$Name.error.log"

    $arguments = @(
        'run'
        'dev'
        '--'
        '--host'
        '127.0.0.1'
        '--port'
        $Port.ToString()
    )

    try {
        Write-LauncherLog "Starting $Name on port $Port"

        $process = Start-Process `
            -FilePath $npmCommand `
            -ArgumentList $arguments `
            -WorkingDirectory $Directory `
            -RedirectStandardOutput $logPath `
            -RedirectStandardError $errorLogPath `
            -PassThru

        Write-LauncherLog "$Name launched with PID $($process.Id)"

        Write-Output "$Name launch requested on http://localhost:$Port (PID: $($process.Id))"
    }
    catch {
        Write-LauncherLog "ERROR: Failed to start $Name. $($_.Exception.Message)"
        throw
    }
}
