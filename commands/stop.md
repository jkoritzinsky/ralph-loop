---
description: "Cancel the active Ralph Loop"
allowed-tools: ["Bash(test -f .copilot/ralph-loop.local.md:*)", "Bash(rm .copilot/ralph-loop.local.md)", "PowerShell(Test-Path .copilot/ralph-loop.local.md:*)", "PowerShell(Remove-Item .copilot/ralph-loop.local.md:*)", "Read(.copilot/ralph-loop.local.md)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph

To cancel the Ralph loop:

1. Check if `.copilot/ralph-loop.local.md` exists:
   - Bash: `test -f .copilot/ralph-loop.local.md && echo "EXISTS" || echo "NOT_FOUND"`
   - PowerShell: `if (Test-Path .copilot/ralph-loop.local.md) { "EXISTS" } else { "NOT_FOUND" }`

2. **If NOT_FOUND**: Say "No active Ralph loop found."

3. **If EXISTS**:
   - Read the state file to get the current iteration number from the `iteration:` field
   - Remove the file:
     - Bash: `rm <state-file-path>`
     - PowerShell: `Remove-Item <state-file-path>`
   - Report: "Cancelled Ralph loop (was at iteration N)" where N is the iteration value
