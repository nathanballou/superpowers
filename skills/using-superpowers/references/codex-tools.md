## Subagent dispatch requires multi-agent support

For V2 workers pinned to Luna at maximum reasoning, use runtime `0.147.0-alpha.10` or newer. The older `0.147.0-alpha.1.2` desktop-bundled runtime rejects Luna workers even when Luna is available in the model picker.

Install and verify the tested terminal runtime:

```bash
npm install --global @openai/codex@0.147.0-alpha.10
hash -r
command -v codex
codex --version
```

Configure `~/.codex/config.toml`:

```toml
[features]
multi_agent = true
multi_agent_v2 = true

[multi_agent_v2]
max_concurrent_threads_per_session = 18
expose_spawn_agent_model_overrides = true

[agents]
max_concurrent_threads_per_session = 8
default_subagent_model = "gpt-5.6-luna"
default_subagent_reasoning_effort = "max"

[agents.luna]
description = "General-purpose worker pinned to Luna at maximum reasoning."
config_file = "agents/luna.toml"
```

Create `~/.codex/agents/luna.toml`:

```toml
name = "luna"
description = "General-purpose worker pinned to Luna at maximum reasoning."
model = "gpt-5.6-luna"
model_reasoning_effort = "max"
developer_instructions = """
Complete the delegated task precisely and return concise, evidence-backed results to the parent agent.
Do not substitute another model.
"""
```

Restart in a fresh terminal process after changing runtime or configuration. Spawn with `agent_type = "luna"` and `fork_turns = "none"`. Do not pass explicit model or reasoning overrides: the custom agent file owns those values. A full-history fork inherits the parent agent type and cannot select the custom Luna role.

Verify a real child session reports all three values before relying on the setup:

```text
model=gpt-5.6-luna
effort=max
multi_agent_version=v2
```

If the router reports `Available models: gpt-5.6-sol, gpt-5.6-terra`, confirm the active terminal resolves to runtime `0.147.0-alpha.10` or newer. Do not substitute another model.

This setup enables `spawn_agent`, `wait_agent`, and `close_agent` for skills like `dispatching-parallel-agents` and `subagent-driven-development`. The V2 cap is session-wide; it is not a recursive worker count per thread.

**Keep workers independent and short-lived.** `close_agent` as soon as a worker's result is collected — implementers included, not just reviewers. Do not hold an agent open expecting to send it more work later.

This matters more on Codex than elsewhere. Worker context is comparatively small and compaction is common, so a worker held open across a commit-and-review cycle is likely to have compacted away the context you were keeping it alive for — and nothing in the tool result tells you that happened. `send_input` also delivers queued rather than interrupting, so a message to a live worker may not be read when you expect. Every unit of work therefore gets its own `spawn_agent` carrying everything it needs: the brief, the report file, the file set, the interfaces, and any findings. The report file on disk is the memory that crosses agent boundaries; a live agent's context is not.

The one exception is a worker that is still mid-task and has asked a question — answering it finishes a turn already in flight. Once a worker has reported, it is done: collect, close, and dispatch fresh for anything further.

### Running a wave concurrently

Skills that fan work out describe it as dispatching everything "in one message" — that is Claude Code's mechanism, where several tool calls in a single turn run concurrently. Codex's equivalent is the order of the two primitives, not the turn boundary:

- `spawn_agent` starts an agent and returns; it does not block.
- `wait_agent` blocks on one agent's result.

So concurrency means **every `spawn_agent` for the wave goes out before your first `wait_agent`**. Collecting may then take one `wait_agent` call or several, depending on how many results a single call returns — that part does not affect concurrency. What does: a `spawn_agent`/`wait_agent` pair per task runs the wave sequentially and throws the parallelism away, even though every individual call looks correct.

Collect results with `wait_agent`, never the bare `wait` tool — `wait` is the exec/wait surface and is not how spawned-agent results are collected.

Your harness may report these tools namespaced (`collaboration.spawn_agent`). The bare names above are what skills reference; use whichever form your tool list actually exposes.

## Environment Detection

Skills that create worktrees or finish branches should detect their
environment with read-only git commands before proceeding:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

- `GIT_DIR != GIT_COMMON` → already in a linked worktree (skip creation)
- `BRANCH` empty → detached HEAD (cannot branch/push/PR from sandbox)

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks branch/push operations (detached HEAD in an
externally managed worktree), the agent commits all work and informs
the user to use the App's native controls:

- **"Create branch"** — names the branch, then commit/push/PR via App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests, stage files, and output suggested branch
names, commit messages, and PR descriptions for the user to copy.
