param([int]$Port = 0)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# ---- pick a free local port -----------------------------------------
function Test-FreePort([int]$p) {
    try {
        $l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $p)
        $l.Start(); $l.Stop(); return $true
    } catch { return $false }
}

if ($Port -le 0) {
    # If a Cortana instance is already running, just reopen it.
    foreach ($p in 8790..8830) {
        try {
            $probe = Invoke-RestMethod "http://127.0.0.1:$p/ping" -TimeoutSec 1
            if ($probe.app -eq 'cortana') {
                Start-Process "http://127.0.0.1:$p/"
                exit 0
            }
        } catch { }
    }
    foreach ($p in 8790..8830) {
        if (Test-FreePort $p) { $Port = $p; break }
    }
}
if ($Port -le 0) {
    Write-Host "No free local port available." -ForegroundColor Red
    exit 1
}

# ---- make sure the local AI stack (llama-swap) is up -----------------
$swapScript = 'E:\ai\_system\scripts\start-swap-hidden.ps1'

function Test-LocalAI {
    try {
        Invoke-RestMethod 'http://127.0.0.1:8080/v1/models' -TimeoutSec 3 | Out-Null
        return $true
    } catch { return $false }
}

$aiRunning = Test-LocalAI
if (-not $aiRunning -and (Test-Path $swapScript)) {
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $swapScript
    ) -WindowStyle Hidden
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-LocalAI) { $aiRunning = $true; break }
    }
}

# ---- internet killswitch --------------------------------------------
$killswitchHelper = Join-Path $root 'killswitch.ps1'
$killswitchState = Join-Path $env:LOCALAPPDATA 'Cortana\killswitch.json'

function Get-UpAdapterNames {
    @(Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Status -eq 'Up' -and
            $_.InterfaceDescription -notmatch 'Loopback'
        } |
        Select-Object -ExpandProperty Name)
}

function Get-KillswitchInfo {
    $active = $false
    $adapters = @()

    if (Test-Path $killswitchState) {
        try {
            $saved = [System.IO.File]::ReadAllText($killswitchState) | ConvertFrom-Json
            $adapters = @($saved.adapters)
            $up = @(Get-UpAdapterNames)
            if ($up.Count -eq 0) {
                $active = $true
            } else {
                # A network adapter came back outside the app: state is stale.
                Remove-Item -LiteralPath $killswitchState -Force -ErrorAction SilentlyContinue
                $adapters = @()
            }
        } catch {
            Remove-Item -LiteralPath $killswitchState -Force -ErrorAction SilentlyContinue
            $adapters = @()
        }
    }

    return [pscustomobject]@{ active = $active; adapters = @($adapters) }
}

function Test-AppHeader($request) {
    return ($request.Headers['X-Cortana'] -eq '1')
}

function Get-PublicIpInfo {
    $local = @()
    try {
        $local = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue |
            Where-Object { $_.IPv4Address -and $_.NetAdapter.Status -eq 'Up' } |
            ForEach-Object {
                [pscustomobject]@{
                    name = $_.InterfaceAlias
                    ip   = @($_.IPv4Address)[0].IPAddress
                }
            })
    } catch { }

    $ks = Get-KillswitchInfo
    if ($ks.active) {
        return [pscustomobject]@{
            ok    = $false
            blocked = $true
            error = 'The killswitch is blocking the internet.'
            local = @($local)
        }
    }

    # Primary lookup: IP + city/country + ISP/org (useful for spotting a VPN).
    try {
        $r = Invoke-RestMethod 'https://ipwho.is/' -TimeoutSec 6 -Headers @{ 'User-Agent' = 'OfflineAI' }
        if ($r -and $r.success -ne $false -and $r.ip) {
            return [pscustomobject]@{
                ok      = $true
                ip      = $r.ip
                country = $r.country
                city    = $r.city
                org     = $r.connection.org
                isp     = $r.connection.isp
                local   = @($local)
            }
        }
    } catch { }

    # Fallback: plain IP, in case the richer service is unavailable.
    try {
        $r = Invoke-RestMethod 'https://api.ipify.org?format=json' -TimeoutSec 6 -Headers @{ 'User-Agent' = 'OfflineAI' }
        if ($r.ip) {
            return [pscustomobject]@{
                ok    = $true
                ip    = $r.ip
                local = @($local)
            }
        }
    } catch { }

    return [pscustomobject]@{
        ok    = $false
        error = 'Could not reach the IP lookup service.'
        local = @($local)
    }
}

function Invoke-Killswitch([bool]$On) {
    if (-not (Test-Path $killswitchHelper)) {
        return [pscustomobject]@{ ok = $false; active = $false; error = 'killswitch.ps1 is missing.' }
    }

    # Fast paths that do not need an administrator prompt.
    if ($On) {
        if (@(Get-UpAdapterNames).Count -eq 0) {
            return [pscustomobject]@{ ok = $false; active = $false; error = 'You are already offline - no active adapters to block.' }
        }
    } elseif (-not (Test-Path $killswitchState)) {
        return [pscustomobject]@{ ok = $true; active = $false }
    }

    $action = if ($On) { 'on' } else { 'off' }
    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" -Action {1} -StatePath "{2}"' -f $killswitchHelper, $action, $killswitchState

    $exitCode = -1
    try {
        $proc = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments -WindowStyle Hidden -PassThru
        if (-not $proc.WaitForExit(90000)) {
            try { $proc.Kill() } catch { }
            return [pscustomobject]@{ ok = $false; active = $false; error = 'Timed out waiting for the administrator prompt.' }
        }
        $exitCode = $proc.ExitCode
    } catch {
        return [pscustomobject]@{ ok = $false; active = $false; error = 'Administrator permission was denied.' }
    }

    # Give Windows a moment to settle the adapter state.
    $info = $null
    for ($i = 0; $i -lt 4; $i++) {
        $info = Get-KillswitchInfo
        if ($On -eq [bool]$info.active) { break }
        Start-Sleep -Milliseconds 700
    }

    if ($On) {
        if ($info.active) {
            return [pscustomobject]@{ ok = $true; active = $true; adapters = @($info.adapters) }
        }
        if ($exitCode -eq 3) {
            return [pscustomobject]@{ ok = $false; active = $false; error = 'You are already offline - no active adapters to block.' }
        }
        return [pscustomobject]@{ ok = $false; active = $false; error = 'Could not disable every network adapter. Check Windows network settings.' }
    }

    if ($exitCode -eq 0) {
        return [pscustomobject]@{ ok = $true; active = $false }
    }
    return [pscustomobject]@{ ok = $false; active = $false; error = 'Some adapters could not be re-enabled. Try again or use Windows settings.' }
}

# ---- serve the interface --------------------------------------------
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")

try {
    $listener.Start()
} catch {
    Write-Host "Could not start the local server on port $Port." -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

function Send-Response($context, [byte[]]$bytes, [string]$contentType, [int]$status = 200) {
    $res = $context.Response
    $res.StatusCode = $status
    $res.ContentType = $contentType
    $res.Headers['Cache-Control'] = 'no-store, no-cache, must-revalidate'
    $res.Headers['Pragma'] = 'no-cache'
    $res.Headers['X-Content-Type-Options'] = 'nosniff'
    $res.Headers['Referrer-Policy'] = 'no-referrer'
    $res.ContentLength64 = $bytes.Length
    try {
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
        $res.OutputStream.Close()
    } catch { }
    try { $res.Close() } catch { }
}

function Send-Json($context, $payload, [int]$status = 200) {
    $json = ($payload | ConvertTo-Json -Depth 5 -Compress)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    Send-Response $context $bytes 'application/json' $status
}

$url = "http://127.0.0.1:$Port/"
$csp = "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' data:; connect-src http: https:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"

$Host.UI.RawUI.WindowTitle = 'Cortana'

Write-Host ""
Write-Host "  Cortana" -ForegroundColor Green -NoNewline
Write-Host "  is running at  $url"
Write-Host "  Local and private. No chat logs. Chat traffic stays on this machine."
if ($aiRunning) {
    Write-Host "  Local AI stack connected (llama-swap, port 8080)." -ForegroundColor DarkGray
} else {
    Write-Host "  Local AI stack did not respond - start E:\ai\AI Launcher.vbs, then press Rescan." -ForegroundColor Yellow
}
Write-Host "  Internet killswitch is in the header (asks for administrator)." -ForegroundColor DarkGray
Write-Host "  Close this window to stop." -ForegroundColor DarkGray
Write-Host ""

Start-Process $url

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
    } catch {
        break
    }

    try {
        $request = $context.Request
        $path = $request.Url.AbsolutePath

        # Only answer to the loopback names this app is served on.
        $allowedHosts = @("127.0.0.1:$Port", "localhost:$Port")
        if ($allowedHosts -notcontains $request.Headers['Host']) {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes('Forbidden')
            Send-Response $context $bytes 'text/plain; charset=utf-8' 403
            continue
        }

        if ($path -eq '/shutdown') {
            if ($request.HttpMethod -eq 'POST' -and (Test-AppHeader $request)) {
                Send-Json $context @{ ok = $true }
                break
            }
            if ($request.HttpMethod -eq 'POST') {
                Send-Json $context @{ ok = $false; error = 'Forbidden' } 403
            } else {
                Send-Json $context @{ ok = $false; error = 'POST required' } 405
            }
        }
        elseif ($path -eq '/myip') {
            if ($request.HttpMethod -ne 'GET') {
                Send-Json $context @{ ok = $false; error = 'Method not allowed' } 405
            } elseif (-not (Test-AppHeader $request)) {
                Send-Json $context @{ ok = $false; error = 'Forbidden' } 403
            } else {
                Send-Json $context (Get-PublicIpInfo)
            }
        }
        elseif ($path -eq '/killswitch') {
            if ($request.HttpMethod -eq 'GET') {
                $info = Get-KillswitchInfo
                Send-Json $context ([ordered]@{
                    ok       = $true
                    active   = [bool]$info.active
                    adapters = @($info.adapters)
                })
            }
            elseif ($request.HttpMethod -eq 'POST') {
                if (-not (Test-AppHeader $request)) {
                    Send-Json $context @{ ok = $false; error = 'Forbidden' } 403
                } else {
                    $on = $request.QueryString['on']
                    if ($on -ne '0' -and $on -ne '1') {
                        Send-Json $context @{ ok = $false; error = 'Use ?on=0 or ?on=1' } 400
                    } else {
                        try {
                            $result = Invoke-Killswitch ($on -eq '1')
                        } catch {
                            $result = [pscustomobject]@{ ok = $false; active = $false; error = $_.Exception.Message }
                        }
                        Send-Json $context $result
                    }
                }
            }
            else {
                Send-Json $context @{ ok = $false; error = 'Method not allowed' } 405
            }
        }
        elseif ($path -eq '/ping') {
            Send-Json $context @{ app = 'cortana' }
        }
        elseif ($path -eq '/' -or $path -eq '/index.html') {
            $file = Join-Path $root 'index.html'
            if (Test-Path $file) {
                $context.Response.Headers['Content-Security-Policy'] = $csp
                $bytes = [System.IO.File]::ReadAllBytes($file)
                Send-Response $context $bytes 'text/html; charset=utf-8'
            } else {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes('index.html is missing')
                Send-Response $context $bytes 'text/plain; charset=utf-8' 404
            }
        }
        elseif ($path -eq '/logo.png') {
            $file = Join-Path $root 'logo.png'
            if (Test-Path $file) {
                $bytes = [System.IO.File]::ReadAllBytes($file)
                Send-Response $context $bytes 'image/png'
            } else {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes('Not found')
                Send-Response $context $bytes 'text/plain; charset=utf-8' 404
            }
        }
        elseif ($path -eq '/favicon.ico') {
            $context.Response.StatusCode = 204
            try { $context.Response.Close() } catch { }
        }
        else {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes('Not found')
            Send-Response $context $bytes 'text/plain; charset=utf-8' 404
        }
    } catch { }
}

try { $listener.Stop() } catch { }
try { $listener.Close() } catch { }
