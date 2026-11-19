param([Parameter(Mandatory)][string]$Godot, [switch]$Windowed)
$ErrorActionPreference = "Stop"
$project = (Resolve-Path (Join-Path $PSScriptRoot "..\game")).Path
$dir = Join-Path ([System.IO.Path]::GetTempPath()) ("punk-exercise-" + [guid]::NewGuid().ToString("N"))
New-Item $dir -ItemType Directory | Out-Null
$clients = @()
try {
    foreach ($n in 1..2) {
        $arguments = @("--path", ('"' + $project + '"'), "--script", "res://client/tests/exercise_flow.gd")
        if (-not $Windowed) { $arguments = @("--headless") + $arguments }
        $clients += Start-Process -FilePath $Godot -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput "$dir/$n.log" -RedirectStandardError "$dir/$n.err"
    }
    foreach ($client in $clients) {
        if (-not $client.WaitForExit(225000)) { throw "客户端超时。日志 $dir" }
        $client.Refresh()
        if ($client.ExitCode -ne 0) { throw "客户端失败。日志 $dir" }
    }
    $outcomes = foreach ($n in 1..2) {
        if (Select-String -Path "$dir/$n.err" -Pattern 'ERROR:|SCRIPT ERROR' -Quiet) { throw "Godot 客户端报错。日志 $dir" }
        $line = Select-String -Path "$dir/$n.log" -Pattern '^EXERCISE_RESULT ([a-f0-9]+) ([a-f0-9]+) '
        if (-not $line) { throw "缺少结算。日志 $dir" }
        $line.Line | Write-Host
        $line.Matches[0].Value
    }
    if ($outcomes[0] -ne $outcomes[1]) { throw "战斗或结算不一致。日志 $dir" }
    Write-Host "EXERCISE_PASS $dir"
} finally {
    $clients | Where-Object { -not $_.HasExited } | Stop-Process
}
