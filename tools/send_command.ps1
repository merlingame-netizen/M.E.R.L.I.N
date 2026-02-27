<#
.SYNOPSIS
    Send a command to the running game via GameObserver command.json.
.DESCRIPTION
    Writes a command file that GameObserver polls every second.
    Actions: screenshot, click_option, set_property, get_tree_snapshot, get_state, mark_card_gen_start
.PARAMETER Action
    Command action to execute.
.PARAMETER Option
    Option index for click_option (0=left, 1=center, 2=right).
.PARAMETER NodePath
    Node path for set_property action.
.PARAMETER Property
    Property name for set_property action.
.PARAMETER Value
    Property value for set_property action.
.PARAMETER Label
    Label for screenshot action.
.EXAMPLE
    .\tools\send_command.ps1 -Action screenshot -Label "before_fix"
    .\tools\send_command.ps1 -Action click_option -Option 0
    .\tools\send_command.ps1 -Action get_tree_snapshot
    .\tools\send_command.ps1 -Action set_property -NodePath "/root/Main/Label" -Property "text" -Value "Hello"
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("screenshot", "click_option", "set_property", "get_tree_snapshot", "get_state", "mark_card_gen_start", "click_button", "change_scene", "list_buttons")]
    [string]$Action,
    [int]$Option = 0,
    [string]$NodePath = "",
    [string]$Property = "",
    [string]$Value = "",
    [string]$Label = "cmd",
    [string]$ButtonName = "",
    [string]$ScenePath = ""
)

$CapturesDir = Join-Path "C:\Users\PGNK2128\Godot-MCP" "tools\autodev\captures"
$CmdPath = Join-Path $CapturesDir "command.json"
$ResultPath = Join-Path $CapturesDir "command_result.json"

# Build params based on action
$params = @{}
switch ($Action) {
    "click_option" { $params["option"] = $Option }
    "set_property" {
        $params["node_path"] = $NodePath
        $params["property"] = $Property
        $params["value"] = $Value
    }
    "screenshot" { $params["label"] = $Label }
    "click_button" { $params["name"] = $ButtonName }
    "change_scene" { $params["scene"] = $ScenePath }
}

# Generate unique command ID
$cmdId = "cmd_" + (Get-Date -Format "yyyyMMdd_HHmmss_fff")

$cmd = @{
    action = $Action
    params = $params
    id = $cmdId
    timestamp = (Get-Date -Format "o")
} | ConvertTo-Json -Depth 3

# Write command
$cmd | Out-File -FilePath $CmdPath -Encoding utf8 -Force
Write-Host "[CMD] Sent: $Action (id=$cmdId)" -ForegroundColor Cyan

# Wait for result (max 5s)
$timeout = 5
$elapsed = 0
while ($elapsed -lt $timeout) {
    Start-Sleep -Milliseconds 500
    $elapsed += 0.5
    if (Test-Path $ResultPath) {
        $result = Get-Content $ResultPath -Raw | ConvertFrom-Json
        if ($result.command_id -eq $cmdId) {
            Write-Host "[RESULT] Status: $($result.status)" -ForegroundColor $(if ($result.status -eq "ok") { "Green" } else { "Red" })
            if ($result.error) {
                Write-Host "[ERROR] $($result.error)" -ForegroundColor Red
            }
            $result | ConvertTo-Json -Depth 5
            exit 0
        }
    }
}

Write-Host "[TIMEOUT] No result after ${timeout}s — game may not be running" -ForegroundColor Yellow
exit 1
