# notify.ps1 --AUTODEV centralized notifications via ntfy.sh
# Extends pattern from ~/.claude/hooks/notify_mobile.ps1

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("cycle_start", "cycle_complete", "worker_done", "worker_blocked",
                 "worker_error", "merge_ok", "merge_conflict", "veto", "health_alert",
                 "wave_start", "wave_complete", "screenshot_done", "stats_done",
                 "review_done", "fix_done")]
    [string]$Event,

    [string]$Domain = "",
    [string]$Message = "",
    [string]$Details = ""
)

$topic = "merlin-cc-346e8cec"
$ntfyUrl = "https://ntfy.sh/$topic"

# Event configuration: title, priority, tags
$eventConfig = @{
    "cycle_start"    = @{ title = "AUTODEV - Cycle Demarre";  priority = "default"; tags = "rocket" }
    "cycle_complete" = @{ title = "AUTODEV - Cycle Termine";  priority = "default"; tags = "white_check_mark" }
    "worker_done"    = @{ title = "AUTODEV - Worker Termine"; priority = "default"; tags = "hammer" }
    "worker_blocked" = @{ title = "AUTODEV - Worker Bloque";  priority = "high";    tags = "warning" }
    "worker_error"   = @{ title = "AUTODEV - ERREUR Worker";  priority = "urgent";  tags = "rotating_light" }
    "merge_ok"       = @{ title = "AUTODEV - Merge OK";       priority = "default"; tags = "merged" }
    "merge_conflict" = @{ title = "AUTODEV - CONFLIT Merge";  priority = "high";    tags = "boom" }
    "veto"           = @{ title = "AUTODEV - STOPPE (Veto)";  priority = "urgent";  tags = "stop_sign" }
    "health_alert"   = @{ title = "AUTODEV - Alerte Sante";   priority = "high";    tags = "stethoscope" }
    "wave_start"     = @{ title = "AUTODEV - Wave Demarre";   priority = "default"; tags = "ocean" }
    "wave_complete"  = @{ title = "AUTODEV - Wave Termine";   priority = "default"; tags = "checkered_flag" }
    "screenshot_done"= @{ title = "AUTODEV - Screenshots OK"; priority = "default"; tags = "camera" }
    "stats_done"     = @{ title = "AUTODEV - Stats Calcules"; priority = "default"; tags = "bar_chart" }
    "review_done"    = @{ title = "AUTODEV - Review Termine"; priority = "default"; tags = "mag" }
    "fix_done"       = @{ title = "AUTODEV - Fixes Appliques";priority = "default"; tags = "wrench" }
}

$config = $eventConfig[$Event]

# Build notification body
$body = if ($Domain) { "[$Domain] $Message" } else { $Message }
if ($Details) { $body += "`n$Details" }

# VS Code tunnel URL for click action
$clickUrl = "https://claude.ai/new"
try {
    $tunnelStatus = & code tunnel status 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($tunnelStatus -and $tunnelStatus.tunnel) {
        $clickUrl = "https://vscode.dev/tunnel/$($tunnelStatus.tunnel.name)/c%3A/Users/PGNK2128/Godot-MCP"
    }
} catch {}

$headers = @{
    "Title"    = $config.title
    "Priority" = $config.priority
    "Tags"     = $config.tags
    "Click"    = $clickUrl
    "Actions"  = "view, Ouvrir VS Code, $clickUrl"
}

try {
    Invoke-RestMethod -Uri $ntfyUrl -Method Post -Body $body -Headers $headers -TimeoutSec 5 | Out-Null
    Write-Host "[NOTIFY] $Event $(if($Domain){"($Domain) "})- $Message"
} catch {
    Write-Host "[NOTIFY] WARN: notification failed (ntfy.sh unreachable)" -ForegroundColor Yellow
}

# Also log to file
$logEntry = @{
    timestamp = (Get-Date -Format "o")
    event     = $Event
    domain    = $Domain
    message   = $Message
    details   = $Details
} | ConvertTo-Json -Compress

$logDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
Add-Content -Path (Join-Path $logDir "notifications.jsonl") -Value $logEntry
