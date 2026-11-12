param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('on', 'off')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$StatePath
)

$ErrorActionPreference = 'Stop'

# All network adapters that can currently reach the internet.
# Loopback is excluded, so the local chat UI keeps working while blocked.
function Get-UpAdapters {
    @(Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Status -eq 'Up' -and
            $_.InterfaceDescription -notmatch 'Loopback'
        })
}

function Write-State($path, $names) {
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $state = [ordered]@{
        active   = $true
        adapters = @($names)
        created  = (Get-Date).ToString('o')
    }
    [System.IO.File]::WriteAllText(
        $path,
        ($state | ConvertTo-Json -Depth 4),
        [System.Text.UTF8Encoding]::new($false)
    )
}

if ($Action -eq 'on') {
    $adapters = @(Get-UpAdapters)
    $names = @($adapters | Select-Object -ExpandProperty Name)

    if ($names.Count -eq 0) {
        # Nothing is connected, so there is nothing to switch off.
        Write-Output 'already-offline'
        exit 3
    }

    # Remember what was on before blocking, so restore is exact.
    Write-State $StatePath $names

    foreach ($name in $names) {
        try { Disable-NetAdapter -Name $name -Confirm:$false -ErrorAction Stop } catch { }
    }

    Start-Sleep -Milliseconds 900
    $stillUp = @(Get-UpAdapters)
    if ($stillUp.Count -eq 0) {
        Write-Output 'blocked'
        exit 0
    }

    Write-Output ('partial:' + (($stillUp | Select-Object -ExpandProperty Name) -join ','))
    exit 2
}

if ($Action -eq 'off') {
    if (-not (Test-Path $StatePath)) {
        Write-Output 'nothing-to-restore'
        exit 0
    }

    $failed = @()
    try {
        $state = [System.IO.File]::ReadAllText($StatePath) | ConvertFrom-Json
        foreach ($name in @($state.adapters)) {
            try { Enable-NetAdapter -Name $name -Confirm:$false -ErrorAction Stop }
            catch { $failed += $name }
        }
    } catch {
        $failed += 'state'
    }

    if ($failed.Count -eq 0) {
        Remove-Item -LiteralPath $StatePath -Force -ErrorAction SilentlyContinue
        Write-Output 'restored'
        exit 0
    }

    Write-Output ('partial:' + ($failed -join ','))
    exit 2
}
