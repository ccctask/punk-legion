param(
    [Parameter(Mandatory)][string]$Godot,
    [int]$Port = 24568,
    [switch]$ExternalServer
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root 'game'
$logs = Join-Path ([IO.Path]::GetTempPath()) ("punk-legion-room-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $logs | Out-Null
$jobs = @()
$server = $null
$oldPort = $env:ROOM_PORT
$oldTestPort = $env:ROOM_TEST_PORT
$oldHost = $env:ROOM_TEST_HOST
$oldGate = $env:ROOM_TEST_GATE
function Launch([string]$name, [string[]]$arguments) {
    Start-Process -FilePath $Godot -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logs "$name.out") -RedirectStandardError (Join-Path $logs "$name.err")
}
try {
    $env:ROOM_PORT = $Port
    $env:ROOM_TEST_PORT = $Port
    $env:ROOM_TEST_HOST = '127.0.0.1'
    $env:ROOM_TEST_GATE = Join-Path $logs 'third-client-rejected'
    $argsBase = @('--headless','--path',('"' + $project + '"'))
    if (!$ExternalServer) {
        $server = Launch 'server' ($argsBase + @('res://net/server.tscn','--','--server'))
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        while (!(Select-String -LiteralPath (Join-Path $logs 'server.out') -Pattern 'ROOM_READY' -Quiet)) {
            if ($server.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw "Server startup failed. Logs: $logs" }
            Start-Sleep -Milliseconds 100
        }
    }
    foreach ($n in 1..2) { $jobs += Launch "client$n" ($argsBase + 'res://net/probe.tscn') }
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    foreach ($n in 1..2) {
        while (!(Select-String -LiteralPath (Join-Path $logs "client$n.out") -Pattern 'PROBE_BOTH_PRESENT' -Quiet)) {
            if ($jobs[$n-1].HasExited -or [DateTime]::UtcNow -gt $deadline) { throw "Admission failed. Logs: $logs" }
            Start-Sleep -Milliseconds 100
        }
    }
    $jobs += Launch 'client3' ($argsBase + @('res://net/probe.tscn','--','--expect-full'))
    if (!$jobs[2].WaitForExit(6000) -or !(Select-String -LiteralPath (Join-Path $logs 'client3.out') -Pattern 'PROBE_FULL_REJECTED' -Quiet)) {
        throw "Full room failed to reject third client. Logs: $logs"
    }
    New-Item -ItemType File -Path $env:ROOM_TEST_GATE | Out-Null
    foreach ($job in $jobs) {
        if (!$job.WaitForExit(26000) -or $job.ExitCode -ne 0) { throw "Room test failed. Logs: $logs" }
    }
    $output = ($jobs | ForEach-Object -Begin {$n=0} -Process {$n++; Get-Content (Join-Path $logs "client$n.out")}) -join [Environment]::NewLine
    foreach ($marker in 'PROBE_PASS seat=1','PROBE_PASS seat=2','PROBE_RESUMED 1','PROBE_RELEASED seat=1','PROBE_RELEASED seat=2') {
        if (!$output.Contains($marker)) { throw "Missing $marker. Logs: $logs" }
    }
    if (Get-ChildItem -LiteralPath $logs -Filter '*.err' | Select-String -Pattern '^(ERROR|SCRIPT ERROR):') {
        throw "Engine reported a runtime error. Logs: $logs"
    }
    Write-Output $output
    Write-Output "Evidence: $logs"
} finally {
    foreach ($p in @($jobs) + @($server)) {
        if ($null -ne $p -and !$p.HasExited) { $p.Kill(); $p.WaitForExit() }
    }
    $env:ROOM_PORT = $oldPort
    $env:ROOM_TEST_PORT = $oldTestPort
    $env:ROOM_TEST_HOST = $oldHost
    $env:ROOM_TEST_GATE = $oldGate
}
