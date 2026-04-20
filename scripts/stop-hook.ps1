$ErrorActionPreference = "Stop"

$hookInput = [Console]::In.ReadToEnd()
$ralphStateFile = ".copilot/ralph-loop.local.md"

if (-not (Test-Path -LiteralPath $ralphStateFile)) {
    exit 0
}

$stateContent = Get-Content -LiteralPath $ralphStateFile -Raw
$frontmatterMatch = [regex]::Match($stateContent, '(?s)^---\r?\n(.*?)\r?\n---')
if (-not $frontmatterMatch.Success) {
    [Console]::Error.WriteLine("⚠️  Ralph loop: corrupted state (frontmatter missing). Stopping.")
    Remove-Item -LiteralPath $ralphStateFile -Force
    exit 0
}

$frontmatter = @{}
foreach ($line in ($frontmatterMatch.Groups[1].Value -split "\r?\n")) {
    if ($line -match '^\s*([^:]+):\s*(.*)\s*$') {
        $frontmatter[$matches[1]] = $matches[2]
    }
}

$iterationRaw = $frontmatter["iteration"]
$maxIterationsRaw = $frontmatter["max_iterations"]
$completionPromiseRaw = $frontmatter["completion_promise"]

if ($completionPromiseRaw -match '^"(.*)"$') {
    $completionPromise = $matches[1]
}
else {
    $completionPromise = $completionPromiseRaw
}

$hookSession = ""
$transcriptPath = ""
if (-not [string]::IsNullOrWhiteSpace($hookInput)) {
    try {
        $hookJson = $hookInput | ConvertFrom-Json -ErrorAction Stop
        if ($null -ne $hookJson.session_id) {
            $hookSession = [string]$hookJson.session_id
        }
        if ($null -ne $hookJson.transcript_path) {
            $transcriptPath = [string]$hookJson.transcript_path
        }
    }
    catch {
    }
}

$stateSession = if ($frontmatter.ContainsKey("session_id")) { [string]$frontmatter["session_id"] } else { "" }
if (-not [string]::IsNullOrWhiteSpace($stateSession) -and $stateSession -ne $hookSession) {
    exit 0
}

$iteration = 0
if (-not [int]::TryParse($iterationRaw, [ref]$iteration) -or $iteration -lt 0) {
    [Console]::Error.WriteLine("⚠️  Ralph loop: corrupted state (iteration='$iterationRaw'). Stopping.")
    Remove-Item -LiteralPath $ralphStateFile -Force
    exit 0
}

$maxIterations = 0
if (-not [int]::TryParse($maxIterationsRaw, [ref]$maxIterations) -or $maxIterations -lt 0) {
    [Console]::Error.WriteLine("⚠️  Ralph loop: corrupted state (max_iterations='$maxIterationsRaw'). Stopping.")
    Remove-Item -LiteralPath $ralphStateFile -Force
    exit 0
}

if ($maxIterations -gt 0 -and $iteration -ge $maxIterations) {
    Write-Output "🛑 Ralph loop: Max iterations ($maxIterations) reached."
    Remove-Item -LiteralPath $ralphStateFile -Force
    exit 0
}

$lastOutput = ""
if (-not [string]::IsNullOrWhiteSpace($transcriptPath)) {
    if (-not (Test-Path -LiteralPath $transcriptPath)) {
        [Console]::Error.WriteLine("⚠️  Ralph loop: Transcript file not found at $transcriptPath")
        [Console]::Error.WriteLine("   This may indicate a Copilot CLI internal issue. Stopping loop.")
        Remove-Item -LiteralPath $ralphStateFile -Force
        exit 0
    }

    $assistantEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($line in (Get-Content -LiteralPath $transcriptPath)) {
        try {
            $entry = $line | ConvertFrom-Json -ErrorAction Stop
            if ($entry.role -eq "assistant") {
                $assistantEntries.Add($entry)
            }
        }
        catch {
            [Console]::Error.WriteLine("⚠️  Ralph loop: Failed to parse transcript JSON. Stopping loop.")
            [Console]::Error.WriteLine("   Error: $($_.Exception.Message)")
            Remove-Item -LiteralPath $ralphStateFile -Force
            exit 0
        }
    }
    if ($assistantEntries.Count -eq 0) {
        [Console]::Error.WriteLine("⚠️  Ralph loop: No assistant messages in transcript. Stopping loop.")
        Remove-Item -LiteralPath $ralphStateFile -Force
        exit 0
    }
    $assistantTexts = [System.Collections.Generic.List[string]]::new()
    $startIndex = [Math]::Max(0, $assistantEntries.Count - 100)
    for ($entryIndex = $startIndex; $entryIndex -lt $assistantEntries.Count; $entryIndex++) {
        $entry = $assistantEntries[$entryIndex]
        if ($entry.message -and $entry.message.content) {
            foreach ($item in $entry.message.content) {
                if ($item.type -eq "text" -and $null -ne $item.text) {
                    $assistantTexts.Add([string]$item.text)
                }
            }
        }
    }

    $lastOutput = $assistantTexts -join "`n"
}

if ($completionPromise -ne "null" -and -not [string]::IsNullOrWhiteSpace($completionPromise) -and -not [string]::IsNullOrWhiteSpace($lastOutput)) {
    $promiseMatch = [regex]::Match($lastOutput, '(?s)<promise>(.*?)</promise>')
    if ($promiseMatch.Success) {
        $promiseText = [regex]::Replace($promiseMatch.Groups[1].Value.Trim(), '\s+', ' ')
        if ($promiseText -eq $completionPromise) {
            Write-Output "✅ Ralph loop: Detected <promise>$completionPromise</promise>"
            Remove-Item -LiteralPath $ralphStateFile -Force
            exit 0
        }
    }
}

$nextIteration = $iteration + 1

$promptMatch = [regex]::Match($stateContent, '(?s)^---\r?\n.*?\r?\n---\r?\n(.*)$')
$promptText = if ($promptMatch.Success) { $promptMatch.Groups[1].Value } else { "" }
$promptText = [regex]::Replace($promptText, '^(?:\s*\r?\n)+', '')

if ([string]::IsNullOrWhiteSpace($promptText)) {
    [Console]::Error.WriteLine("⚠️  Ralph loop: no prompt found in state file. Stopping.")
    Remove-Item -LiteralPath $ralphStateFile -Force
    exit 0
}

$tempFile = "$ralphStateFile.tmp.$PID"
$stateLines = Get-Content -LiteralPath $ralphStateFile
$iterationUpdated = $false
for ($i = 0; $i -lt $stateLines.Count; $i++) {
    if ($stateLines[$i] -match '^iteration:\s*') {
        $stateLines[$i] = "iteration: $nextIteration"
        $iterationUpdated = $true
        break
    }
}
if (-not $iterationUpdated) {
    [Console]::Error.WriteLine("⚠️  Ralph loop: corrupted state (iteration field missing). Stopping.")
    Remove-Item -LiteralPath $ralphStateFile -Force
    exit 0
}
Set-Content -LiteralPath $tempFile -Value $stateLines
Move-Item -LiteralPath $tempFile -Destination $ralphStateFile -Force

$systemMsg = if ($completionPromise -ne "null" -and -not [string]::IsNullOrWhiteSpace($completionPromise)) {
    "🔄 Ralph iteration $nextIteration | To stop: output <promise>$completionPromise</promise> (ONLY when TRUE)"
}
else {
    "🔄 Ralph iteration $nextIteration | No completion promise set - loop continues until max iterations or /ralph-loop:stop"
}

$result = @{
    decision      = "block"
    reason        = $promptText
    systemMessage = $systemMsg
}
$result | ConvertTo-Json -Compress

exit 0
