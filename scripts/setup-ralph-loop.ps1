$ErrorActionPreference = "Stop"

$promptParts = [System.Collections.Generic.List[string]]::new()
[int]$maxIterations = 0
$completionPromise = "null"

for ($i = 0; $i -lt $args.Count;) {
    switch ($args[$i]) {
        { $_ -in @("-h", "--help") } {
            @'
Ralph Loop - Iterative self-referential development loop for Copilot CLI

USAGE:
  /ralph-loop [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Task description for the loop (can be multiple words)

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase that signals completion
  -h, --help                     Show this help message

DESCRIPTION:
  Starts a Ralph Loop in your CURRENT Copilot CLI session. The agentStop
  hook prevents exit and feeds your output back as input until the
  completion promise is detected or the iteration limit is reached.

  To signal completion, output: <promise>YOUR_PHRASE</promise>

EXAMPLES:
  /ralph-loop Build a todo API --completion-promise 'DONE' --max-iterations 20
  /ralph-loop --max-iterations 10 Fix the auth bug
  /ralph-loop Refactor cache layer  (runs until cancelled)

STOPPING:
  • Reaching --max-iterations
  • Detecting --completion-promise in <promise>...</promise> tags
  • Manually: /cancel-ralph

MONITORING:
  Select-String '^iteration:' .copilot/ralph-loop.local.md
  Get-Content .copilot/ralph-loop.local.md -Head 10
'@
            exit 0
        }
        "--max-iterations" {
            if ($i + 1 -ge $args.Count) {
                [Console]::Error.WriteLine("❌ Error: --max-iterations requires a non-negative integer")
                [Console]::Error.WriteLine("   Examples: --max-iterations 10, --max-iterations 50")
                exit 1
            }

            $candidate = $args[$i + 1]
            $parsedValue = 0
            if (-not [int]::TryParse($candidate, [ref]$parsedValue) -or $parsedValue -lt 0) {
                [Console]::Error.WriteLine("❌ Error: --max-iterations requires a non-negative integer")
                [Console]::Error.WriteLine("   Examples: --max-iterations 10, --max-iterations 50")
                exit 1
            }

            $maxIterations = $parsedValue
            $i += 2
            continue
        }
        "--completion-promise" {
            if ($i + 1 -ge $args.Count -or [string]::IsNullOrWhiteSpace($args[$i + 1])) {
                [Console]::Error.WriteLine("❌ Error: --completion-promise requires a text argument")
                [Console]::Error.WriteLine("   Examples: --completion-promise 'DONE', --completion-promise 'All tests passing'")
                exit 1
            }
            $completionPromise = $args[$i + 1]
            $i += 2
            continue
        }
        default {
            $promptParts.Add($args[$i])
            $i += 1
            continue
        }
    }
}

$prompt = ($promptParts -join " ").Trim()

if ([string]::IsNullOrWhiteSpace($prompt)) {
    [Console]::Error.WriteLine("❌ Error: No prompt provided")
    [Console]::Error.WriteLine("   Example: /ralph-loop Build a REST API --completion-promise 'DONE' --max-iterations 20")
    [Console]::Error.WriteLine("   For help: /ralph-loop --help")
    exit 1
}

[void](New-Item -ItemType Directory -Path ".copilot" -Force)

if (-not [string]::IsNullOrWhiteSpace($completionPromise) -and $completionPromise -ne "null") {
    $escapedPromise = $completionPromise.Replace('\', '\\').Replace('"', '\"')
    $completionPromiseYaml = '"' + $escapedPromise + '"'
}
else {
    $completionPromiseYaml = "null"
}

$sessionId = if ($env:COPILOT_SESSION_ID) { $env:COPILOT_SESSION_ID } elseif ($env:CLAUDE_CODE_SESSION_ID) { $env:CLAUDE_CODE_SESSION_ID } else { "" }
$startedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$stateContent = @"
---
active: true
iteration: 1
session_id: $sessionId
max_iterations: $maxIterations
completion_promise: $completionPromiseYaml
started_at: "$startedAt"
---

$prompt
"@

Set-Content -Path ".copilot/ralph-loop.local.md" -Value $stateContent

$maxIterationsText = if ($maxIterations -gt 0) { "$maxIterations" } else { "unlimited" }
$completionDisplay = if ($completionPromise -ne "null") { $completionPromise.Replace('"', "") } else { "none (runs until cancelled or max iterations)" }

@"
🔄 Ralph loop activated!

Iteration: 1
Max iterations: $maxIterationsText
Completion promise: $completionDisplay

The agentStop hook is now active. When the agent finishes responding,
the SAME PROMPT will be fed back, creating a self-referential loop
where each iteration sees your previous work in files and git history.

To cancel: /ralph-loop:stop
To monitor: Get-Content .copilot/ralph-loop.local.md -Head 10
"@

if ($completionPromise -ne "null") {
    Write-Output ""
    Write-Output "To complete this loop, output EXACTLY:"
    Write-Output "  <promise>$completionPromise</promise>"
    Write-Output ""
    Write-Output "⚠️  The promise MUST be TRUE when you output it. Do not lie to exit."
}
