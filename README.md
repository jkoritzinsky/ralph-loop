# Ralph Loop — Copilot CLI Plugin

Iterative, self-referential development loops for GitHub Copilot CLI. Run the same prompt repeatedly until task completion, implementing the [Ralph Wiggum technique](https://ghuntley.com/ralph/).

## How It Works

Ralph Loop uses an `agentStop` hook to intercept the agent's exit. When the agent finishes responding to your prompt, the hook:

1. Checks for an active loop state file (`.copilot/ralph-loop.local.md`)
2. If a completion promise was set, checks the agent's last output for `<promise>...</promise>` tags
3. If the task is not complete and the iteration limit hasn't been reached, **blocks the exit** and feeds the same prompt back
4. The agent sees its previous work in files and git history, enabling autonomous iterative improvement

```
You run ONCE:
  /ralph-loop:start "Your task" --completion-promise "DONE" --max-iterations 20

Copilot CLI automatically:
  1. Works on the task
  2. Finishes responding
  3. agentStop hook blocks exit
  4. Hook feeds the SAME prompt back
  5. Repeat until completion
```

## Installation

```bash
# From a local clone
git clone https://github.com/YOUR_USER/ralph-loop.git
copilot plugin install ./ralph-loop

# Or directly from your GitHub repo
copilot plugin install YOUR_USER/ralph-loop
```

Verify it loaded:

```bash
copilot plugin list
```

## Commands

### `/ralph-loop:start`

Start a Ralph loop in the current session.

```
/ralph-loop:start Build a REST API for todos --completion-promise 'DONE' --max-iterations 20
```

Supports both Unix shell scripts (`.sh`) and Windows PowerShell scripts (`.ps1`).

**Options:**

| Flag | Description | Default |
|------|-------------|---------|
| `--max-iterations <n>` | Stop after N iterations | unlimited |
| `--completion-promise '<text>'` | Phrase that signals task completion | none |

### `/ralph-loop:stop`

Cancel the active Ralph loop immediately.

```
/ralph-loop:stop
```

## Prompt Writing Tips

### Clear Completion Criteria

```
Build a REST API for todos.

When complete:
- All CRUD endpoints working
- Input validation in place
- Tests passing (coverage > 80%)
- Output: <promise>COMPLETE</promise>
```

### Incremental Goals

```
Phase 1: User authentication (JWT, tests)
Phase 2: Product catalog (list/search, tests)
Phase 3: Shopping cart (add/remove, tests)

Output <promise>COMPLETE</promise> when all phases done.
```

### TDD Self-Correction

```
Implement feature X following TDD:
1. Write failing tests
2. Implement feature
3. Run tests
4. If any fail, debug and fix
5. Repeat until all green
7. Output: <promise>COMPLETE</promise>
```

### Always Use Safety Limits

```bash
# Recommended: always set a max
/ralph-loop:start "Implement feature X" --max-iterations 20 --completion-promise 'DONE'
```

## When to Use Ralph

**Good for:**
- Well-defined tasks with clear success criteria
- Tasks requiring iteration (getting tests to pass)
- Greenfield projects where you can walk away
- Tasks with automatic verification (tests, linters)

**Not good for:**
- Tasks requiring human judgment or design decisions
- One-shot operations
- Tasks with unclear success criteria

## Monitoring

```bash
# Check current iteration
grep '^iteration:' .copilot/ralph-loop.local.md

# View full state
head -10 .copilot/ralph-loop.local.md
```

## Plugin Structure

```
ralph-loop/
├── plugin.json                # Plugin manifest (required)
├── hooks.json                 # Hook configuration (agentStop)
├── commands/                  # Slash commands
│   ├── start.md               # /ralph-loop:start command
│   └── stop.md                # /ralph-loop:stop command
├── scripts/                   # Hook/setup scripts (bash + pwsh)
│   ├── setup-ralph-loop.sh    # Loop initialization
│   ├── setup-ralph-loop.ps1   # Loop initialization (Windows)
│   ├── stop-hook.sh           # agentStop hook script
│   └── stop-hook.ps1          # agentStop hook script (Windows)
└── README.md
```

## Credits

Based on the [Ralph Wiggum technique](https://ghuntley.com/ralph/) by Geoffrey Huntley. Adapted for GitHub Copilot CLI's plugin and hook system.

## License

MIT
