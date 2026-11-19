param([Parameter(Mandatory)][string]$Godot, [int]$RoomPort=24586, [int]$ProfilePort=24686)
$ErrorActionPreference = "Stop"
$project = "punk-reward-" + [guid]::NewGuid().ToString("N").Substring(0,10)
$base = "http://127.0.0.1:$ProfilePort"
$accounts = @()
$backup = @{}
foreach ($name in @("ROOM_PORT","ROOM_HOST_PORT","PROFILE_HOST_PORT","ROOM_TEST_TICKET1","ROOM_TEST_TICKET2")) {
    $backup[$name] = [Environment]::GetEnvironmentVariable($name)
}
function Compose {
    & docker compose -p $project @args
    if ($LASTEXITCODE -ne 0) { throw "Compose failed" }
}
function Post($route,$body,$headers=@{}) {
    Invoke-RestMethod -Method Post -Uri "$base$route" -ContentType "application/json" -Headers $headers -Body (ConvertTo-Json $body -Compress)
}
try {
    $env:ROOM_HOST_PORT="$RoomPort"
    $env:ROOM_PORT="$RoomPort"
    $env:PROFILE_HOST_PORT="$ProfilePort"
    Compose up -d --build room profile
    $limit = [DateTime]::UtcNow.AddSeconds(25)
    do {
        try {
            Invoke-WebRequest "$base/v1/profile" -SkipHttpErrorCheck -TimeoutSec 2 | Out-Null
            break
        } catch {
            if ([DateTime]::UtcNow -ge $limit) { throw }
            Start-Sleep -Milliseconds 300
        }
    } while ($true)
    foreach ($n in 1..2) {
        $credential = @{name="ledger$n"; password=[guid]::NewGuid().ToString("N")}
        $login = Post "/v1/accounts" $credential
        $headers = @{Authorization="Bearer " + $login.token}
        $admission = Post "/v1/inventory/admit" @{key=[guid]::NewGuid().ToString("N")} $headers
        [Environment]::SetEnvironmentVariable("ROOM_TEST_TICKET$n", $admission.receipt.ticket)
        $accounts += $headers
    }
    Compose stop -t 1 profile
    & (Join-Path $PSScriptRoot "exercise-smoke.ps1") -Godot $Godot
    $pending = @(Compose exec -T room ls /var/lib/punk-room | Where-Object {$_ -match '\.json$'})
    if ($pending.Length -ne 1) { throw "Expected one atomic battle manifest" }
    $battle = [IO.Path]::GetFileNameWithoutExtension($pending[0])
    $manifestPath = "/var/lib/punk-room/" + $pending[0]
    $manifest = (Compose exec -T room cat $manifestPath) | ConvertFrom-Json
    if ($manifest.deliveries.Count -ne 2) { throw "Both recipients must exist before sending" }
    Compose restart -t 1 room
    Compose start profile
    # Stop the consumer after the first HTTP receipt and manifest checkpoint.
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 100
        $remaining = (Compose exec -T room cat $manifestPath) | ConvertFrom-Json
    } while ($remaining.deliveries.Count -ne 1 -and [DateTime]::UtcNow -lt $deadline)
    if ($remaining.deliveries.Count -ne 1) { throw "First recipient was not checkpointed" }
    Compose stop -t 0 room
    # Simulate an old-format single delivery still present from before the upgrade.
    $first = $manifest.deliveries | Where-Object { $_.ticket -ne $remaining.deliveries[0].ticket }
    $legacyCopy = Join-Path ([IO.Path]::GetTempPath()) ("punk-legacy-" + [guid]::NewGuid().ToString("N") + ".json")
    try {
        [IO.File]::WriteAllText($legacyCopy, (ConvertTo-Json $first -Compress))
        Compose cp $legacyCopy "room:/var/lib/punk-room/legacy.json"
    } finally {
        if (Test-Path -LiteralPath $legacyCopy) { Remove-Item -LiteralPath $legacyCopy }
    }
    Compose start room
    $deadline = [DateTime]::UtcNow.AddSeconds(35)
    do {
        Start-Sleep -Milliseconds 600
        $pending = @(Compose exec -T room ls /var/lib/punk-room)
    } while ($pending.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline)
    if ($pending.Count -gt 0) { throw "Outbox did not drain" }
    foreach ($headers in $accounts) {
        $inventory = (Invoke-RestMethod "$base/v1/inventory" -Headers $headers).inventory
        $rewards = @($inventory.ledger | Where-Object { $_.operation -eq "reward" -and $_.battle -eq $battle })
        if ($rewards.Length -ne 1 -or $inventory.pending_ticket) { throw "Account did not receive one settled result" }
    }
    Write-Host "ROOM_LEDGER_PASS battle=$battle recipients=2 pending=0"
} finally {
    & docker compose -p $project down -t 1 -v
    foreach ($name in $backup.Keys) { [Environment]::SetEnvironmentVariable($name,$backup[$name]) }
}


