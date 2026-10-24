```powershell
$ErrorActionPreference = 'Stop'

# Jenkins configuration
$jenkinsUrl  = 'http://localhost:8080/'
$javaPath    = 'C:\Program Files\Eclipse Adoptium\jdk-21.0.12.8-hotspot\bin\java.exe'
$warPath     = 'C:\Users\RITIK\Downloads\jenkins.war'
$jenkinsHome = 'C:\Users\RITIK\.jenkins'
$logDirectory = 'C:\tmp'

$stdoutPath = Join-Path $logDirectory 'jenkins-shortcut.stdout.log'
$stderrPath = Join-Path $logDirectory 'jenkins-shortcut.stderr.log'

$port = 8080
$startupTimeoutSeconds = 60

# Ensure log directory exists
New-Item -ItemType Directory -Path $logDirectory -Force |
    Out-Null

# Validate required files
foreach ($path in @($javaPath, $warPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file not found: $path"
    }
}

# Check whether Jenkins is accepting connections
function Test-JenkinsRunning {
    $client = $null

    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $connection = $client.BeginConnect(
            '127.0.0.1',
            $port,
            $null,
            $null
        )

        if (-not $connection.AsyncWaitHandle.WaitOne(500)) {
            return $false
        }

        $client.EndConnect($connection)
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($client) {
            $client.Dispose()
        }
    }
}

# Start Jenkins only when the port is not already listening
if (-not (Test-JenkinsRunning)) {
    New-Item -ItemType Directory -Path $jenkinsHome -Force |
        Out-Null

    Start-Process `
        -FilePath $javaPath `
        -ArgumentList @(
            '-Xms256m',
            '-Xmx512m',
            "-DJENKINS_HOME=$jenkinsHome",
            '-jar',
            "`"$warPath`"",
            '--httpPort=8080'
        ) `
        -WorkingDirectory (Split-Path -Parent $warPath) `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath |
        Out-Null
}

# Wait for Jenkins to start
$deadline = [DateTime]::UtcNow.AddSeconds(
    $startupTimeoutSeconds
)

while ([DateTime]::UtcNow -lt $deadline) {
    if (Test-JenkinsRunning) {
        Start-Process $jenkinsUrl
        exit 0
    }

    Start-Sleep -Milliseconds 500
}

# Open the URL even if startup timed out, allowing the browser
# to display Jenkins' current status.
Start-Process $jenkinsUrl

exit 1
```
