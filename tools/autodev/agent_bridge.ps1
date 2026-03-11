# agent_bridge.ps1 — Inter-Agent Communication Bridge v2.0
# Protocol: JSON FIFO message bus for orchestrator_v2
# Usage: . "$PSScriptRoot\agent_bridge.ps1"  (dot-source to import functions)

$BRIDGE_ROOT = $PSScriptRoot
$MESSAGES_FILE = "$BRIDGE_ROOT\status\agent_messages.json"
$STATUS_FILE = "$BRIDGE_ROOT\status\agent_status.json"
$MAX_MESSAGE_AGE_HOURS = 24

# Priority ordering for sorting (lower index = higher priority)
$PRIORITY_ORDER = @{ "CRITICAL" = 0; "HIGH" = 1; "MEDIUM" = 2; "LOW" = 3 }

# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

# _Invoke-WithFileLock — Wraps a scriptblock with a named system mutex to
# prevent race conditions when multiple agents read/write the same file.
function _Invoke-WithFileLock {
    param(
        [string]$MutexName,
        [scriptblock]$Action
    )
    $mutex = New-Object System.Threading.Mutex($false, "Global\MerlinBridge_$MutexName")
    $acquired = $false
    try {
        $acquired = $mutex.WaitOne(5000)  # 5s timeout
        if ($acquired) {
            & $Action
        } else {
            Write-Warning "[AgentBridge] Mutex timeout for $MutexName — skipping operation"
        }
    } catch {
        Write-Warning "[AgentBridge] Error in locked block for $MutexName`: $_"
    } finally {
        if ($acquired) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

# _Write-JsonAtomic — Writes JSON to a temp file then renames atomically to
# avoid partial reads by other agents during write.
function _Write-JsonAtomic {
    param(
        [string]$Path,
        [object]$Data
    )
    $tempPath = "$Path.tmp"
    try {
        $Data | ConvertTo-Json -Depth 20 | Set-Content -Path $tempPath -Encoding UTF8
        Move-Item -Path $tempPath -Destination $Path -Force
    } catch {
        Write-Warning "[AgentBridge] Atomic write failed for $Path`: $_"
        if (Test-Path $tempPath) { Remove-Item $tempPath -Force -ErrorAction SilentlyContinue }
    }
}

# _Read-JsonFile — Safely reads a JSON file, returns null on failure.
function _Read-JsonFile {
    param([string]$Path)
    try {
        if (-not (Test-Path $Path)) {
            Write-Warning "[AgentBridge] File not found: $Path"
            return $null
        }
        $content = Get-Content -Path $Path -Raw -Encoding UTF8
        return $content | ConvertFrom-Json
    } catch {
        Write-Warning "[AgentBridge] Failed to read/parse $Path`: $_"
        return $null
    }
}

# _Get-IsoTimestamp — Returns current UTC time in ISO8601 format.
function _Get-IsoTimestamp {
    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

# _ConvertTo-Hashtable — Recursively converts PSCustomObject to hashtable
# so we can merge and modify fields freely.
function _ConvertTo-Hashtable {
    param([object]$InputObject)
    if ($null -eq $InputObject) { return @{} }
    if ($InputObject -is [hashtable]) { return $InputObject }
    $ht = @{}
    $InputObject.PSObject.Properties | ForEach-Object {
        $val = $_.Value
        if ($val -is [System.Management.Automation.PSCustomObject]) {
            $ht[$_.Name] = _ConvertTo-Hashtable $val
        } elseif ($val -is [System.Object[]] -or $val -is [System.Collections.ArrayList]) {
            $ht[$_.Name] = @($val)
        } else {
            $ht[$_.Name] = $val
        }
    }
    return $ht
}

# ---------------------------------------------------------------------------
# PUBLIC FUNCTIONS
# ---------------------------------------------------------------------------

# Send-AgentMessage — Posts a new message onto the FIFO bus.
# Returns the generated message ID on success, null on failure.
function Send-AgentMessage {
    param(
        [Parameter(Mandatory)][string]$FromAgent,
        [Parameter(Mandatory)][string]$ToAgent,
        [Parameter(Mandatory)][string]$Type,
        [string]$Priority = "MEDIUM",
        [hashtable]$Payload = @{}
    )

    $messageId = $null

    _Invoke-WithFileLock -MutexName "Messages" -Action {
        $data = _Read-JsonFile -Path $MESSAGES_FILE
        if ($null -eq $data) { return }

        $dataHt = _ConvertTo-Hashtable $data

        # Generate unique ID
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $rand = (Get-Random -Maximum 999).ToString('D3')
        $msgId = "msg_${timestamp}_${rand}"

        # Build message object
        $message = @{
            id         = $msgId
            from_agent = $FromAgent
            to_agent   = $ToAgent
            type       = $Type
            priority   = $Priority
            payload    = $Payload
            timestamp  = _Get-IsoTimestamp
            status     = "pending"
            handled_at = $null
        }

        # Append to messages array
        $messages = if ($dataHt["messages"]) { [System.Collections.ArrayList]@($dataHt["messages"]) } else { [System.Collections.ArrayList]@() }
        [void]$messages.Add($message)
        $dataHt["messages"] = @($messages)

        # Update stats
        if (-not $dataHt["stats"]) { $dataHt["stats"] = @{} }
        $stats = _ConvertTo-Hashtable $dataHt["stats"]
        $stats["total_sent"] = ([int]($stats["total_sent"] ?? 0)) + 1
        $stats["last_message_id"] = $msgId
        $dataHt["stats"] = $stats

        _Write-JsonAtomic -Path $MESSAGES_FILE -Data $dataHt

        $messageId = $msgId
    }

    return $messageId
}

# Read-PendingMessages — Returns pending messages filtered by optional criteria.
# Does NOT mark messages as handled (read-only operation).
function Read-PendingMessages {
    param(
        [string]$ToAgent,
        [string]$Type,
        [string]$Priority
    )

    $data = _Read-JsonFile -Path $MESSAGES_FILE
    if ($null -eq $data) { return @() }

    $messages = @($data.messages) | Where-Object {
        $_.status -eq "pending"
    }

    # Filter by recipient (exact match or broadcast)
    if ($ToAgent) {
        $messages = $messages | Where-Object {
            $_.to_agent -eq $ToAgent -or $_.to_agent -eq "broadcast"
        }
    }

    # Optional type filter
    if ($Type) {
        $messages = $messages | Where-Object { $_.type -eq $Type }
    }

    # Optional priority filter
    if ($Priority) {
        $messages = $messages | Where-Object { $_.priority -eq $Priority }
    }

    # Sort: CRITICAL first, then by timestamp ascending
    $sorted = $messages | Sort-Object {
        $p = $PRIORITY_ORDER[$_.priority]
        if ($null -eq $p) { $p = 99 }
        $p
    }, { $_.timestamp }

    return @($sorted)
}

# Mark-MessageHandled — Marks a message as handled and records the timestamp.
function Mark-MessageHandled {
    param(
        [Parameter(Mandatory)][string]$MessageId
    )

    _Invoke-WithFileLock -MutexName "Messages" -Action {
        $data = _Read-JsonFile -Path $MESSAGES_FILE
        if ($null -eq $data) { return }

        $dataHt = _ConvertTo-Hashtable $data
        $messages = [System.Collections.ArrayList]@($dataHt["messages"])

        $found = $false
        for ($i = 0; $i -lt $messages.Count; $i++) {
            $msg = _ConvertTo-Hashtable $messages[$i]
            if ($msg["id"] -eq $MessageId) {
                $msg["status"] = "handled"
                $msg["handled_at"] = _Get-IsoTimestamp
                $messages[$i] = $msg
                $found = $true
                break
            }
        }

        if (-not $found) {
            Write-Warning "[AgentBridge] Mark-MessageHandled: message '$MessageId' not found"
            return
        }

        $dataHt["messages"] = @($messages)

        # Update stats
        $stats = _ConvertTo-Hashtable $dataHt["stats"]
        $stats["total_handled"] = ([int]($stats["total_handled"] ?? 0)) + 1
        $dataHt["stats"] = $stats

        _Write-JsonAtomic -Path $MESSAGES_FILE -Data $dataHt
    }
}

# Archive-OldMessages — Moves handled messages older than MAX_MESSAGE_AGE_HOURS
# to "archived" status. Called by orchestrator at each cycle start.
function Archive-OldMessages {
    _Invoke-WithFileLock -MutexName "Messages" -Action {
        $data = _Read-JsonFile -Path $MESSAGES_FILE
        if ($null -eq $data) { return }

        $dataHt = _ConvertTo-Hashtable $data
        $messages = [System.Collections.ArrayList]@($dataHt["messages"])
        $cutoff = (Get-Date).ToUniversalTime().AddHours(-$MAX_MESSAGE_AGE_HOURS)
        $archived = 0

        for ($i = 0; $i -lt $messages.Count; $i++) {
            $msg = _ConvertTo-Hashtable $messages[$i]
            if ($msg["status"] -eq "handled") {
                try {
                    $msgTime = [datetime]::Parse($msg["timestamp"]).ToUniversalTime()
                    if ($msgTime -lt $cutoff) {
                        $msg["status"] = "archived"
                        $messages[$i] = $msg
                        $archived++
                    }
                } catch {
                    Write-Warning "[AgentBridge] Could not parse timestamp for message $($msg['id'])"
                }
            }
        }

        $dataHt["messages"] = @($messages)
        _Write-JsonAtomic -Path $MESSAGES_FILE -Data $dataHt

        if ($archived -gt 0) {
            Write-Host "[AgentBridge] Archived $archived old message(s)"
        }
    }
}

# Update-AgentStatus — Updates an agent's state and optional extra fields
# in agent_status.json. Thread-safe via mutex.
function Update-AgentStatus {
    param(
        [Parameter(Mandatory)][string]$AgentName,
        [Parameter(Mandatory)][ValidateSet("idle","running","waiting","done","error","blocked")]
        [string]$State,
        [hashtable]$AdditionalFields = @{}
    )

    _Invoke-WithFileLock -MutexName "Status" -Action {
        $data = _Read-JsonFile -Path $STATUS_FILE
        if ($null -eq $data) { return }

        $dataHt = _ConvertTo-Hashtable $data
        if (-not $dataHt["agents"]) { $dataHt["agents"] = @{} }

        $agents = _ConvertTo-Hashtable $dataHt["agents"]

        # Get or create agent entry
        $agent = if ($agents[$AgentName]) { _ConvertTo-Hashtable $agents[$AgentName] } else { @{} }

        # Update core fields
        $agent["state"] = $State
        $agent["last_active"] = _Get-IsoTimestamp

        # Merge any additional fields
        foreach ($key in $AdditionalFields.Keys) {
            $agent[$key] = $AdditionalFields[$key]
        }

        $agents[$AgentName] = $agent
        $dataHt["agents"] = $agents
        $dataHt["last_updated"] = _Get-IsoTimestamp

        _Write-JsonAtomic -Path $STATUS_FILE -Data $dataHt
    }
}

# Get-AgentStatus — Returns the status object for a specific agent,
# or the entire agents hashtable if no name is given.
function Get-AgentStatus {
    param(
        [string]$AgentName
    )

    $data = _Read-JsonFile -Path $STATUS_FILE
    if ($null -eq $data) { return $null }

    if ($AgentName) {
        return $data.agents.$AgentName
    }
    return $data.agents
}

# Broadcast-Event — Sends a message addressed to "broadcast" so all agents
# can receive it. Returns the message ID.
function Broadcast-Event {
    param(
        [Parameter(Mandatory)][string]$FromAgent,
        [Parameter(Mandatory)][string]$EventType,
        [hashtable]$Payload = @{},
        [string]$Priority = "MEDIUM"
    )

    return Send-AgentMessage `
        -FromAgent $FromAgent `
        -ToAgent "broadcast" `
        -Type $EventType `
        -Priority $Priority `
        -Payload $Payload
}

# Register-ParallelAgent — Attempts to claim a parallel execution slot.
# Returns $true if a slot was available and claimed, $false otherwise.
function Register-ParallelAgent {
    param(
        [Parameter(Mandatory)][string]$AgentName
    )

    $result = $false

    _Invoke-WithFileLock -MutexName "Status" -Action {
        $data = _Read-JsonFile -Path $STATUS_FILE
        if ($null -eq $data) { return }

        $dataHt = _ConvertTo-Hashtable $data
        $slots = _ConvertTo-Hashtable $dataHt["parallel_slots"]

        $max  = [int]($slots["max"]  ?? 3)
        $used = [int]($slots["used"] ?? 0)
        $inParallel = [System.Collections.ArrayList]@($slots["agents_in_parallel"] ?? @())

        if ($used -lt $max) {
            if (-not $inParallel.Contains($AgentName)) {
                [void]$inParallel.Add($AgentName)
            }
            $slots["used"] = $used + 1
            $slots["agents_in_parallel"] = @($inParallel)
            $dataHt["parallel_slots"] = $slots
            $dataHt["last_updated"] = _Get-IsoTimestamp
            _Write-JsonAtomic -Path $STATUS_FILE -Data $dataHt
            $result = $true
        } else {
            Write-Warning "[AgentBridge] No parallel slot available (used=$used, max=$max)"
        }
    }

    return $result
}

# Unregister-ParallelAgent — Releases a parallel execution slot previously
# claimed by Register-ParallelAgent.
function Unregister-ParallelAgent {
    param(
        [Parameter(Mandatory)][string]$AgentName
    )

    _Invoke-WithFileLock -MutexName "Status" -Action {
        $data = _Read-JsonFile -Path $STATUS_FILE
        if ($null -eq $data) { return }

        $dataHt = _ConvertTo-Hashtable $data
        $slots = _ConvertTo-Hashtable $dataHt["parallel_slots"]

        $used = [int]($slots["used"] ?? 0)
        $inParallel = [System.Collections.ArrayList]@($slots["agents_in_parallel"] ?? @())

        if ($inParallel.Contains($AgentName)) {
            [void]$inParallel.Remove($AgentName)
            $slots["used"] = [Math]::Max(0, $used - 1)
        } else {
            Write-Warning "[AgentBridge] Unregister-ParallelAgent: '$AgentName' was not in parallel list"
        }

        $slots["agents_in_parallel"] = @($inParallel)
        $dataHt["parallel_slots"] = $slots
        $dataHt["last_updated"] = _Get-IsoTimestamp
        _Write-JsonAtomic -Path $STATUS_FILE -Data $dataHt
    }
}

# ---------------------------------------------------------------------------
# EXPORTS
# ---------------------------------------------------------------------------

Export-ModuleMember -Function @(
    'Send-AgentMessage',
    'Read-PendingMessages',
    'Mark-MessageHandled',
    'Archive-OldMessages',
    'Update-AgentStatus',
    'Get-AgentStatus',
    'Broadcast-Event',
    'Register-ParallelAgent',
    'Unregister-ParallelAgent'
)
